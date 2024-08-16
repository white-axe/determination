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
#include <iostream>
#include <semaphore.h>
#include <jack/ringbuffer.h>
#include "source/jackbridge/JackBridge.hpp"
#include "source/includes/CarlaNativePlugin.h"

sem_t semaphore;

enum State {
    Running,
    Done,
    Xrun,
    SemFail,
};
std::atomic<State> state;

#define BUFFER_SIZE 67108864
jack_ringbuffer_t *rb;
char buf[BUFFER_SIZE];

CarlaHostHandle handle;
FILE *pipe;
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

void post() {
    if (sem_post(&semaphore))
        state.store(SemFail);
}

void stop_and_post(State val) {
    jackbridge_transport_stop(client);
    state.store(val);
    post();
}

int process(jack_nframes_t nframes, void *_null) {
    // Do nothing if rendering has stopped
    if (state.load() != Running)
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
        stop_and_post(Done);
        return 0;
    }

    // Write the data we received on our input ports to the ringbuffer
    float *samplesL = (float *)jackbridge_port_get_buffer(recorderL, nframes);
    float *samplesR = (float *)jackbridge_port_get_buffer(recorderR, nframes);
    for (jack_nframes_t i = 0; i < nframes; ++i) {
        // Get a sample from each channel, convert them from 32-bit floating point to signed 24-bit integer and push to the ringbuffer
        // NOTE: Assumes the CPU is little-endian
        int32_t sample;

        sample = std::roundf(std::clamp(*(samplesL++), -1.0f, 1.0f) * 8388607.0f);
        if (jack_ringbuffer_write_space(rb) < 3) {
            stop_and_post(Xrun);
            return 0;
        }
        jack_ringbuffer_write(rb, (char *)&sample, 3);

        sample = std::roundf(std::clamp(*(samplesR++), -1.0f, 1.0f) * 8388607.0f);
        if (jack_ringbuffer_write_space(rb) < 3) {
            stop_and_post(Xrun);
            return 0;
        }
        jack_ringbuffer_write(rb, (char *)&sample, 3);
    }

    // Tell the main thread we've written something
    post();

    return 0;
}

bool render(char *projectPath) {
    std::cerr << "[determination-renderer] Loading \"" << projectPath << "\"" << std::endl;
    if (!carla_load_project(handle, projectPath)) {
        error = carla_get_last_error(handle);
        return false;
    }

    // Enable freewheeling so the audio rendering happens faster than realtime
    std::cerr << "[determination-renderer] Enabling JACK freewheel mode" << std::endl;
    if (jackbridge_set_freewheel(client, true)) {
        error = "Failed to enable JACK freewheel mode";
        return false;
    }

    // Make JACK call `process()` every time new audio samples are available to be processed
    determination_set_process_callback(handle, process, NULL);

    std::cerr << "[determination-renderer] Starting JACK transport" << std::endl;
    carla_transport_play(handle);

    std::cerr << "[determination-renderer] Rendering audio" << std::endl;
    for (;;) {
        // Block this thread until `process()` posts to the semaphore
        if (sem_wait(&semaphore)) {
            error = "Failed to wait for semaphore to be posted";
            state.store(SemFail);
            return false;
        }

        switch (state.load()) {
            case Running:
                break;
            case Done:
                return true;
            case Xrun:
                error = "Buffer overrun";
                return false;
            case SemFail:
                error = "Failed to post semaphore";
                return false;
        }

        // If `process()` is still running, write all received samples to the pipe
        size_t space;
        while ((space = jack_ringbuffer_read_space(rb))) {
            size_t count = space < BUFFER_SIZE ? space : BUFFER_SIZE;
            std::fwrite(buf, 1, jack_ringbuffer_read(rb, buf, count), pipe);
        }
    }
}

int main(int argc, char **argv) {
    std::cerr << "[determination-renderer] Initializing" << std::endl;
    if (sem_init(&semaphore, 0, 0)) {
        std::cerr << "\e[91m[determination-renderer] Failed to initialize semaphore\e[0m" << std::endl;
        return 1;
    }
    state.store(Running);
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
    if ((pipe = std::fopen("/determination-renderer-pipe", "a")) == NULL) {
        std::cerr << "\e[91m[determination-renderer] Failed to open pipe\e[0m" << std::endl;
        return 1;
    }
    rb = jack_ringbuffer_create(BUFFER_SIZE);

    bool ok = render(argv[1]);
    if (!ok)
        std::cerr << "\e[91m[determination-renderer] " << error << "\e[0m" << std::endl;
    else
        std::cerr << "[determination-renderer] Rendering finished!" << std::endl;

    jack_ringbuffer_free(rb);
    std::fclose(pipe);

    // `carla_engine_close()` modifies the JACK graph,
    // which is not permitted when freewheeling is enabled,
    // so disable freewheeling first
    jackbridge_set_freewheel(client, false);
    carla_engine_close(handle);

    return ok ? 0 : 1;
}
