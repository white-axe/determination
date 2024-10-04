# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
pkgs.stdenv.mkDerivation {
  pname = "rubberband";
  version = "2024-10-03";
  src = pkgs.fetchFromGitHub {
    owner = "breakfastquay";
    repo = "rubberband";
    rev = "48e08a5113ced935451833e554d39f8fca31276f";
    hash = "sha256-XY5GqUDToULthExTEPheUkDZ41IWYxkKfudXNM7TjPw=";
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
  mesonBuildType = "minsize";
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
}
