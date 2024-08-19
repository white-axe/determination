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
#include <semaphore.h>
#include "source/jackbridge/JackBridge.hpp"
#include "source/includes/CarlaNativePlugin.h"

sem_t semaphore;

enum State {
    Ok,
    PipeFail,
};
std::atomic<State> state;

uint8_t buf[6 * 8192]; // Large enough for a JACK buffer size of 8192

CarlaHostHandle handle;
FILE *pipeFile;
jack_client_t *client;
jack_port_t *recorderL;
jack_port_t *recorderR;

int32_t startBar;
int32_t startBeat;
int32_t startTick;
int32_t endBar;
int32_t endBeat;
int32_t endTick;

const char *error = NULL;

jack_client_t *determination_get_jack_client(CarlaHostHandle handle);
void determination_set_process_callback(CarlaHostHandle handle, JackProcessCallback callback, void *arg);

void stop_and_post(State val) {
    jackbridge_transport_stop(client);
    state.store(val);
    sem_post(&semaphore);
}

int process(jack_nframes_t nframes, void *_null) {
    // Do nothing if rendering has stopped
    if (state.load() != Ok)
        return 0;

    // Do nothing if JACK transport isn't playing
    jack_position_t pos;
    if (jackbridge_transport_query(client, &pos) != JackTransportRolling)
        return 0;

    // Do nothing if JACK transport hasn't reached the start position yet
    if (pos.bar < startBar || (pos.bar == startBar && (pos.beat < startBeat || (pos.beat == startBeat && pos.tick < startTick))))
        return 0;

    // Stop once the JACK transport has reached the end position
    if (pos.bar > endBar || (pos.bar == endBar && (pos.beat > endBeat || (pos.beat == endBeat && pos.tick >= endTick)))) {
        stop_and_post(Ok);
        return 0;
    }

    // Get the data we received on our input ports and copy to our internal buffer
    const float *samplesL = (float *)jackbridge_port_get_buffer(recorderL, nframes);
    const float *samplesR = (float *)jackbridge_port_get_buffer(recorderR, nframes);
    uint8_t *buffer = buf;
    for (jack_nframes_t i = 0; i < nframes; ++i) {
        // Get a sample from each channel and convert them from 32-bit floating point to signed 24-bit integer
        // NOTE: Assumes the CPU is little-endian
        int32_t sample;

        sample = std::lround(std::clamp((double)*(samplesL++) * 8388608., -8388608., 8388607.));
        std::memcpy(buffer, &sample, 3);
        buffer += 3;

        sample = std::lround(std::clamp((double)*(samplesR++) * 8388608., -8388608., 8388607.));
        std::memcpy(buffer, &sample, 3);
        buffer += 3;
    }

    // Writing to the pipe isn't realtime-safe, but freewheeling should be enabled by now so it's fine
    if (std::fwrite(buf, 6, nframes, pipeFile) < nframes)
        stop_and_post(PipeFail);

    return 0;
}

bool render(char *projectPath) {
    std::cerr << "[determination-renderer] Loading \"" << projectPath << "\"" << std::endl;
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
    determination_set_process_callback(handle, process, NULL);

    std::cerr << "[determination-renderer] Starting JACK transport" << std::endl;
    carla_transport_play(handle);

    // Block this thread until `process()` posts to the semaphore
    std::cerr << "[determination-renderer] Rendering audio" << std::endl;
    while (sem_wait(&semaphore)) {
        // If a signal handler is called while `sem_wait()` is waiting,
        // `sem_wait()` may stop waiting and return with a nonzero return value after the signal handler returns.
        // We actually want to continue waiting for the semaphore to be posted in that case,
        // hence why we're spinning here.
    }

    switch (state.load()) {
        case Ok:
            return true;
        case PipeFail:
            error = "Broken pipe";
            break;
    }

    return false;
}

int main(int argc, char **argv) {
    std::cerr << "[determination-renderer] Initializing" << std::endl;
    state.store(Ok);
    startBar = std::strtol(argv[2], NULL, 10);
    startBeat = std::strtol(argv[3], NULL, 10);
    startTick = std::strtol(argv[4], NULL, 10);
    endBar = std::strtol(argv[5], NULL, 10);
    endBeat = std::strtol(argv[6], NULL, 10);
    endTick = std::strtol(argv[7], NULL, 10);
    handle = carla_standalone_host_init();
    if (!carla_engine_init(handle, "JACK", "DeterminationRenderer")) {
        std::cerr << "\e[91m[determination-renderer] " << carla_get_last_error(handle) << "\e[0m" << std::endl;
        return 1;
    }
    client = determination_get_jack_client(handle);
    recorderL = jackbridge_port_by_name(client, "DeterminationRenderer:RecorderL");
    recorderR = jackbridge_port_by_name(client, "DeterminationRenderer:RecorderR");

    std::cerr << "[determination-renderer] Opening pipe for writing PCM data" << std::endl;
    if ((pipeFile = std::fopen("/determination-renderer-pipe", "a")) == NULL) {
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

    sem_destroy(&semaphore);
    std::fclose(pipeFile);

    // `carla_engine_close()` modifies the JACK graph,
    // which is not permitted when freewheeling is enabled,
    // so disable freewheeling first
    jackbridge_set_freewheel(client, false);
    carla_engine_close(handle);

    return ok ? 0 : 1;
}
