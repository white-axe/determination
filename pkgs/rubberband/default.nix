# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
let
  version = "3.3.0";
in
pkgs.stdenv.mkDerivation {
  pname = "rubberband";
  inherit version;
  src = pkgs.fetchFromGitHub {
    owner = "breakfastquay";
    repo = "rubberband";
    rev = "v${version}";
    hash = "sha256-CybAsHHJp8lPUsfQjlfD2Arei7oK4DFwk2cCjUso2Ek=";
  };
  nativeBuildInputs = [
    pkgs.meson
    pkgs.ninja
    pkgs.pkg-config
  ];
  buildInputs = [
    (pkgs.callPackage ../fftw { })
    pkgs.libsamplerate
    pkgs.lv2
  ];
  mesonFlags = [
    "-Dcmdline=disabled"
    "-Ddefault_library=static"
    "-Dfft=fftw"
    "-Djni=disabled"
    "-Dladspa=disabled"
    "-Dlv2=enabled"
    "-Dresampler=libsamplerate"
    "-Dtests=disabled"
    "-Dvamp=disabled"
  ];
  mesonBuildType = "minsize";
}
