/*
 * Determination - Deterministic rendering environment for white-axe's music
 * Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#include <algorithm>
#include <atomic>
#include <cstring>
#include <iostream>
#include <iomanip>
#include <mutex>
#include <semaphore.h>
#include "carla/source/jackbridge/JackBridge.hpp"
#include "carla/source/includes/CarlaNativePlugin.h"

static sem_t semaphore;

enum State {
    WaitForRenderFinish,
    WaitForFreewheelOn,
    WaitForFreewheelOff,
    Ok,
    PipeFail,
};
static std::atomic<State> state;

static jack_time_t elapsedTime;
static jack_position_t currentPos;
static std::mutex mutex;

static uint8_t buf[6 * 8192]; // Large enough for a JACK buffer size of 8192

static CarlaHostHandle handle;
static FILE *pipeFile;
static jack_client_t *client;
static jack_port_t *recorderL;
static jack_port_t *recorderR;

static int32_t startBar;
static int32_t startBeat;
static int32_t startTick;
static int32_t endBar;
static int32_t endBeat;
static int32_t endTick;
static jack_time_t progressDelay;

static const char *error = NULL;

jack_client_t *determination_get_jack_client(CarlaHostHandle handle);
void determination_set_process_callback(CarlaHostHandle handle, void (*callback)(jack_nframes_t, bool));

inline void post() {
    sem_post(&semaphore);
}

inline void post(State val) {
    state.store(val);
    post();
}

inline State wait() {
    while (sem_wait(&semaphore)) {
        // If a signal handler is called while `sem_wait()` is waiting,
        // `sem_wait()` may stop waiting and return with a nonzero return value after the signal handler returns.
        // We actually want to continue waiting for the semaphore to be posted in that case,
        // hence why we're spinning here.
    }
    return state.load();
}

inline State wait(State val) {
    state.store(val);
    return wait();
}

inline void drain() {
    while (sem_trywait(&semaphore) == 0 || errno != EAGAIN) { }
}

inline void update_progress(jack_position_t *pos, jack_time_t newElapsedTime) {
    // Locking a mutex isn't realtime-safe, but freewheeling should be enabled by now so it's fine
    mutex.lock();
    elapsedTime = newElapsedTime;
    currentPos = *pos;
    mutex.unlock();
}

inline int32_t convert_sample(float sample) {
    return std::isnan(sample) ? 0 : std::lround(std::clamp((double)sample * 8388608., -8388608., 8388607.));
}

static void process(jack_nframes_t nframes, bool freewheel) {
    switch (state.load()) {
        case WaitForRenderFinish:
            break;
        case WaitForFreewheelOn:
            if (freewheel)
                post(Ok);
            return;
        case WaitForFreewheelOff:
            if (!freewheel)
                post(Ok);
            return;
        default:
            return;
    }

    // Do nothing if JACK transport isn't playing
    jack_position_t pos;
    if (jackbridge_transport_query(client, &pos) != JackTransportRolling)
        return;

    static jack_time_t startTime = pos.usecs;
    static jack_time_t elapsedDelayIntervals = 0;
    jack_time_t newElapsedTime = pos.usecs - startTime;

    // Stop once the JACK transport has reached the end position
    if (pos.bar > endBar || (pos.bar == endBar && (pos.beat > endBeat || (pos.beat == endBeat && pos.tick >= endTick)))) {
        jackbridge_transport_stop(client);
        update_progress(&pos, newElapsedTime);
        post(Ok);
        return;
    }

    // Notify the main thread of our progress after a user-specified time has passed, but continue rendering
    jack_time_t newElapsedDelayIntervals = newElapsedTime / progressDelay;
    if (newElapsedDelayIntervals > elapsedDelayIntervals) {
        elapsedDelayIntervals = newElapsedDelayIntervals;
        update_progress(&pos, newElapsedTime);
        post();
    }

    // Do nothing if JACK transport hasn't reached the start position yet
    if (pos.bar < startBar || (pos.bar == startBar && (pos.beat < startBeat || (pos.beat == startBeat && pos.tick < startTick))))
        return;

    // Get the data we received on our input ports and copy to our internal buffer
    const float *samplesL = (float *)jackbridge_port_get_buffer(recorderL, nframes);
    const float *samplesR = (float *)jackbridge_port_get_buffer(recorderR, nframes);
    uint8_t *buffer = buf;
    for (jack_nframes_t i = 0; i < nframes; ++i) {
        // Get a sample from each channel and convert them from 32-bit floating point to signed 24-bit integer
        // NOTE: Assumes the CPU is little-endian
        int32_t sample;

        sample = convert_sample(*(samplesL++));
        std::memcpy(buffer, &sample, 3);
        buffer += 3;

        sample = convert_sample(*(samplesR++));
        std::memcpy(buffer, &sample, 3);
        buffer += 3;
    }

    // Writing to the pipe isn't realtime-safe, but freewheeling should be enabled by now so it's fine
    if (std::fwrite(buf, 6, nframes, pipeFile) < nframes) {
        jackbridge_transport_stop(client);
        update_progress(&pos, newElapsedTime);
        post(PipeFail);
    }
}

static void log_progress() {
    mutex.lock();
    jack_time_t elapsed = elapsedTime;
    bool shown = false;
    std::cerr << std::setfill('0') << "[determination-renderer]";
    if (elapsed >= 24ll * 60ll * 60ll * 1000000ll) {
        shown = true;
        std::cerr << ' ' << elapsed / (24ll * 60ll * 60ll * 1000000ll) << 'd';
    }
    elapsed %= 24ll * 60ll * 60ll * 1000000ll;
    if (shown || elapsed >= 60ll * 60ll * 1000000ll) {
        shown = true;
        std::cerr << ' ' << std::setw(2) << elapsed / (60ll * 60ll * 1000000ll) << 'h';
    }
    elapsed %= 60ll * 60ll * 1000000ll;
    if (shown || elapsed >= 60ll * 1000000ll) {
        shown = true;
        std::cerr << ' ' << std::setw(2) << elapsed / (60ll * 1000000ll) << 'm';
    }
    elapsed %= 60ll * 1000000ll;
    std::cerr << ' ' << std::setw(2) << elapsed / 1000000ll << 's';
    elapsed %= 1000000ll;
    std::cerr << ' ' << std::setfill('0') << std::setw(6) << elapsed << "us";
    std::cerr << "    " << std::setfill('0') << std::setw(3) << currentPos.bar << '|' << std::setw(2) << currentPos.beat << '|' << std::setw(4) << currentPos.tick;
    std::cerr << "    " << currentPos.frame + 1 << " frames" << std::endl;
    mutex.unlock();
}

inline bool render(char *projectPath) {
    std::cerr << "[determination-renderer] Loading \"" << projectPath << '"' << std::endl;
    if (!carla_load_project(handle, projectPath)) {
        error = carla_get_last_error(handle);
        return false;
    }

    // Enable freewheeling so the audio rendering happens faster than realtime
    // We can't do this before loading the project because loading the project modifies the JACK graph
    // and that's not permitted when freewheeling is enabled
    std::cerr << "[determination-renderer] Enabling JACK freewheel mode" << std::endl;
    if (jackbridge_set_freewheel(client, true)) {
        error = "Failed to enable JACK freewheel mode";
        return false;
    }

    // Make JACK call `process()` every time new audio samples are available to be processed
    determination_set_process_callback(handle, process);

    // Block this thread until `process()` detects that freewheeling is enabled
    wait(WaitForFreewheelOn);

    std::cerr << "[determination-renderer] Starting JACK transport" << std::endl;
    carla_transport_play(handle);

    // Block this thread until `process()` detects that the JACK transport has reached the end position or an error occurred
    std::cerr << "[determination-renderer] Rendering audio" << std::endl;
    State result = wait(WaitForRenderFinish);
    for (;;) {
        switch (result) {
            case WaitForRenderFinish:
                log_progress();
                break;
            case Ok:
                log_progress();
                return true;
            case PipeFail:
                log_progress();
                error = "Broken pipe";
                return false;
            default:
                break;
        }
        result = wait();
    }
}

int main(int argc, char **argv) {
    std::cerr << "[determination-renderer] Initializing" << std::endl;
    startBar = std::strtol(argv[2], NULL, 10);
    startBeat = std::strtol(argv[3], NULL, 10);
    startTick = std::strtol(argv[4], NULL, 10);
    endBar = std::strtol(argv[5], NULL, 10);
    endBeat = std::strtol(argv[6], NULL, 10);
    endTick = std::strtol(argv[7], NULL, 10);
    progressDelay = std::strtoll(argv[8], NULL, 10);
    handle = carla_standalone_host_init();
    if (!carla_engine_init(handle, "JACK", "DeterminationRenderer")) {
        std::cerr << "\e[91m[determination-renderer] " << carla_get_last_error(handle) << "\e[0m" << std::endl;
        return 1;
    }
    client = determination_get_jack_client(handle);
    recorderL = jackbridge_port_by_name(client, "DeterminationRenderer:RecorderL");
    recorderR = jackbridge_port_by_name(client, "DeterminationRenderer:RecorderR");

    std::cerr << "[determination-renderer] Opening pipe for writing PCM data" << std::endl;
    if ((pipeFile = std::fopen("/.determination-renderer-pipe", "a")) == NULL) {
        std::cerr << "\e[91m[determination-renderer] Failed to open pipe\e[0m" << std::endl;
        carla_engine_close(handle);
        return 1;
    }
    if (sem_init(&semaphore, 0, 0)) {
        std::cerr << "\e[91m[determination-renderer] Failed to initialize semaphore\e[0m" << std::endl;
        std::fclose(pipeFile);
        carla_engine_close(handle);
        return 1;
    }

    bool ok = render(argv[1]);
    if (!ok)
        std::cerr << "\e[91m[determination-renderer] " << error << "\e[0m" << std::endl;
    else
        std::cerr << "[determination-renderer] Rendering finished!" << std::endl;
    drain();

    // `carla_engine_close()` modifies the JACK graph,
    // which is not permitted when freewheeling is enabled,
    // so disable freewheeling first
    std::cerr << "[determination-renderer] Disabling JACK freewheel mode" << std::endl;
    if (jackbridge_set_freewheel(client, false)) {
        std::cerr << "[determination-renderer] Failed to disable JACK freewheel mode" << std::endl;
    } else {
        // Block this thread until `process()` detects that freewheeling is disabled
        wait(WaitForFreewheelOff);
    }

    std::cerr << "[determination-renderer] Cleaning up" << std::endl;
    sem_destroy(&semaphore);
    std::fclose(pipeFile);
    carla_engine_close(handle);

    return ok ? 0 : 1;
}
