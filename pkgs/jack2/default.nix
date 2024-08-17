# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
let
  version = "1.9.22";
in
pkgs.stdenv.mkDerivation {
  pname = "jack2";
  inherit version;
  src = pkgs.fetchFromGitHub {
    owner = "jackaudio";
    repo = "jack2";
    rev = "v${version}";
    sha256 = "sha256-Cslfys5fcZDy0oee9/nM5Bd1+Cg4s/ayXjJJOSQCL4E=";
  };
  nativeBuildInputs = [
    pkgs.makeWrapper
    pkgs.pkg-config
    pkgs.python3
    pkgs.wafHook
  ];
  buildInputs = [ pkgs.eigen ];
  postPatch = ''
    patchShebangs --build svnversion_regenerate.sh
  '';
  dontAddWafCrossFlags = true;
  wafConfigureFlags = [
    "--clients=2048"
    "--ports-per-application=256"
    "--alsa=no"
    "--autostart=classic"
    "--celt=no"
    "--classic"
    "--firewire=no"
    "--iio=no"
    "--portaudio=no"
    "--winmme=no"
  ];
}
