# Determination - Deterministic rendering environment for music and art
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
{ pkgs }:
let
  version = "0.4.9";
in
  pkgs.stdenv.mkDerivation {
    name = "aubio";
    version = version;
    src = pkgs.fetchurl {
      url = "https://aubio.org/pub/aubio-${version}.tar.bz2";
      sha256 = "1npks71ljc48w6858l9bq30kaf5nph8z0v61jkfb70xb9np850nl";
    };
    nativeBuildInputs = [
      pkgs.pkg-config
      pkgs.python3
      pkgs.wafHook
    ];
    buildInputs = [
      pkgs.alsa-lib
      (pkgs.callPackage ./fftw.nix { })
      pkgs.libjack2
      pkgs.libsamplerate
      pkgs.libsndfile
    ];
    postPatch = ''
      substituteInPlace waflib/*.py --replace "m='rU" "m='r" --replace "'rU'" "'r'"
    '';
  }
