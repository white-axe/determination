# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

cmake_minimum_required(VERSION 3.15)
project(determination-renderer)
add_subdirectory(carla/cmake)
add_executable(determination-renderer)
set_property(TARGET determination-renderer PROPERTY CXX_STANDARD 20)
target_link_libraries(determination-renderer PUBLIC carla::standalone jack)
target_sources(determination-renderer PRIVATE renderer.cpp)
