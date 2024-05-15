# Determination - Deterministic rendering environment for music and art
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
{ pkgs }:
let
  version = "8.4";
in
pkgs.stdenv.mkDerivation {
  pname = "ardour";
  inherit version;
  src = pkgs.fetchgit {
    url = "https://git.ardour.org/ardour/ardour";
    rev = version;
    hash = "sha256-6qx/elkj4Kb4YK1JZG/S036WdUO7wEE6/yf4pZQP8J0=";
  };
  patches = [
    ./ardour-disable-fpu-optimization.patch
    ./ardour-disable-gui.patch
    ./ardour-disable-timestamp-warning.patch
  ];
  nativeBuildInputs = [
    pkgs.itstool
    pkgs.makeWrapper
    pkgs.pkg-config
    pkgs.python3
    pkgs.wafHook
  ];
  buildInputs = [
    pkgs.alsa-lib
    (pkgs.callPackage ./aubio.nix { })
    pkgs.boost
    pkgs.cairomm
    pkgs.curl
    (pkgs.callPackage ./fftw.nix { })
    pkgs.flac
    pkgs.fluidsynth
    pkgs.glibmm
    pkgs.libarchive
    pkgs.liblo
    pkgs.libltc
    pkgs.libogg
    pkgs.libsamplerate
    pkgs.libsigcxx
    pkgs.libsndfile
    pkgs.libxml2
    pkgs.lilv
    pkgs.lv2
    pkgs.readline
    pkgs.rubberband
    pkgs.serd
    pkgs.sord
    pkgs.sratom
    pkgs.taglib
    pkgs.vamp-plugin-sdk
  ];
  wafConfigureFlags = [
    "--cxx11"
    "--no-phone-home"
    "--no-ytk"
    "--with-backends=dummy"
  ];
  postPatch = ''
    printf '#include "libs/ardour/ardour/revision.h"\nnamespace ARDOUR { const char* revision = "${version}"; const char* date = ""; }\n' > libs/ardour/revision.cc
  '';
}
