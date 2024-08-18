# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
let
  version = "2.3.5";
in
pkgs.stdenv.mkDerivation {
  pname = "fluidsynth";
  inherit version;
  src = pkgs.fetchFromGitHub {
    owner = "FluidSynth";
    repo = "fluidsynth";
    rev = "v${version}";
    sha256 = "sha256-CzKfvQzhF4Mz2WZaJM/Nt6XjF6ThlX4jyQSaXfZukG8=";
  };
  nativeBuildInputs = [
    pkgs.cmake
    pkgs.pkg-config
  ];
  buildInputs = [ pkgs.glib ];
  cmakeFlags = [
    "-Denable-framework=off"
    "-Denable-ipv6=off"
    "-Denable-network=off"
    "-Denable-openmp=off"
    "-Denable-oss=off"
    "-Denable-threads=off"
  ];
}
