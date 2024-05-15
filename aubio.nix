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
  pname = "aubio";
  inherit version;
  src = pkgs.fetchurl {
    url = "https://aubio.org/pub/aubio-${version}.tar.bz2";
    hash = "sha256-1IKCrk2rg7PclMFs8BG8tjg1wcArUVSQ4YgwScPR89o=";
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
