# Determination - Deterministic rendering environment for music and art
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
{
  # Include the ability to render Krita projects in the Docker image
  krita = true;
  # Include the ability to render Ardour projects in the Docker image
  ardour = true;
  # Include FFmpeg in the Docker image
  ffmpeg = true;
  # Include FLAC tools in the Docker image
  flac = true;
  # Include ExifTool in the Docker image
  exiftool = true;
  # Include Zopfli in the Docker image
  zopfli = true;
  # Include ZynAddSubFX in the Docker image (required for Ardour projects that use this synthesizer)
  zynaddsubfx = true;
}
