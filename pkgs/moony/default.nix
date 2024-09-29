# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
pkgs.stdenv.mkDerivation {
  pname = "moony";
  version = "0.41.215";
  src = pkgs.fetchFromSourcehut {
    domain = "open-music-kontrollers.ch";
    owner = "~hp";
    repo = "moony.lv2";
    rev = "0f2b47428cc58322f7cf03c12c713142840459d5";
    hash = "sha256-bEqAZn3FfBje+IADC8H9EJc037BAJw0jh2KDQ3UI1gI=";
  };
  patches = [
    ./disable-ui.patch
    ./entropy.patch
    ./sync.patch
  ];
  nativeBuildInputs = [
    pkgs.meson
    pkgs.cmake
    pkgs.fontconfig
    pkgs.ninja
    pkgs.pkg-config
  ];
  buildInputs = [ pkgs.lv2 ];
  mesonBuildType = "minsize";
  mesonFlags = [
    "-Dbuild-tests=false"
    "-Dbuild-ui=false"
  ];
}
