# Determination - Deterministic rendering environment for music and art
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
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
