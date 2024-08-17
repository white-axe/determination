# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
let
  version = "0.90.3";
in
pkgs.stdenv.mkDerivation {
  pname = "calf";
  inherit version;
  src = pkgs.fetchFromGitHub {
    owner = "calf-studio-gear";
    repo = "calf";
    rev = version;
    hash = "sha256-V2TY1xmV223cnc6CxaTuvLHqocVVIkQlbSI6Z0VTH00=";
  };
  patches = [ ./fpu.patch ];
  nativeBuildInputs = [
    pkgs.autoreconfHook
    pkgs.pkg-config
  ];
  buildInputs = [
    pkgs.expat
    (pkgs.callPackage ../fftw { })
    pkgs.fluidsynth
    pkgs.glib
    pkgs.lv2
  ];
}
