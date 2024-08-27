# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
let
  version = "2.74.6";
in
pkgs.stdenv.mkDerivation {
  pname = "faust";
  inherit version;
  src = pkgs.fetchFromGitHub {
    owner = "grame-cncm";
    repo = "faust";
    rev = version;
    fetchSubmodules = true;
    hash = "sha256-0r7DjTrsNKZ5ZmWoA+Y9OXyJFUiUFZiPQb1skXXWYTw=";
  };
  patches = [
    ./box.patch
    ./share.patch
  ];
  nativeBuildInputs = [
    pkgs.cmake
    pkgs.pkg-config
  ];
  outputs = [
    "out"
    "dsplibs"
  ];
  preConfigure = ''
    cd build
  '';
  cmakeBuildType = "MinSizeRel";
  cmakeFlags = [
    "-DC_BACKEND=STATIC"
    "-DCPP_BACKEND=STATIC"
    "-DINTERP_BACKEND=STATIC"
    "-DINCLUDE_EXECUTABLE=OFF"
    "-DINCLUDE_STATIC=ON"
    "-DINCLUDE_DYNAMIC=OFF"
    "-DINCLUDE_OSC=OFF"
    "-DINCLUDE_HTTP=OFF"
    "-DOSCDYNAMIC=OFF"
    "-DHTTPDYNAMIC=OFF"
    "-DINCLUDE_ITP=OFF"
    "-DITPDYNAMIC=OFF"
    "-DSELF_CONTAINED_LIBRARY=ON"
  ];
  postFixup = ''
    mkdir "$dsplibs"
    mv "$out/share" "$dsplibs/"
  '';
}
