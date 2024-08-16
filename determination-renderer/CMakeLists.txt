# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

cmake_minimum_required(VERSION 3.15)
project(determination-renderer)

set(DETERMINATION_CARLA_PATH carla CACHE PATH "Path to Carla source code directory")
add_subdirectory(${DETERMINATION_CARLA_PATH}/cmake carla)

add_executable(determination-renderer)
target_link_libraries(determination-renderer PUBLIC carla::standalone jack)
target_include_directories(determination-renderer PRIVATE ${DETERMINATION_CARLA_PATH})
target_sources(determination-renderer PRIVATE renderer.cpp)
