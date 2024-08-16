# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
let
  version = "2.16";
in
pkgs.stdenv.mkDerivation {
  pname = "lcms2";
  inherit version;
  src = pkgs.fetchurl {
    url = "mirror://sourceforge/lcms/lcms2-${version}.tar.gz";
    hash = "sha256-2HPTSti5tM6gEGMfGmIo0gh0deTcXnY+uBrMI9nUWlE=";
  };
  configureFlags = [ "CPPFLAGS=-DCMS_DONT_USE_SSE2=1" ];
}
