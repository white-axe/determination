# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{
  # Include the ability to render Ardour projects in the image
  ardour = true;
  # Include FFmpeg in the image
  ffmpeg = true;
  # Include FLAC tools in the image
  flac = true;
  # Include ZynAddSubFX in the image (required for Ardour projects that use this synthesizer)
  zynaddsubfx = true;
}
