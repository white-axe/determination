# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
pkgs.stdenv.mkDerivation {
  pname = "rubberband";
  version = "2024-09-24";
  src = pkgs.fetchFromGitHub {
    owner = "breakfastquay";
    repo = "rubberband";
    rev = "e55f7aaadca759af1d589a525328524b4cda1216";
    hash = "sha256-2TScJetJ45iAIj9usfaVfy2a1OAzH0PK2max/9M3IAo=";
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
