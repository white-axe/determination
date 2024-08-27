# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
let
  version = "0.18.2";
  faust = pkgs.callPackage ../faust { };
in
pkgs.stdenv.mkDerivation {
  pname = "mephisto";
  inherit version;
  src = pkgs.fetchFromSourcehut {
    domain = "open-music-kontrollers.ch";
    owner = "~hp";
    repo = "mephisto.lv2";
    rev = version;
    hash = "sha256-ab6OGt1XVgynKNdszzdXwJ/jVKJSzgSmAv6j1U3/va0=";
  };
  patches = [
    ./disable-ui.patch
    ./interpreter.patch
    ./px.patch
    ./sync.patch
  ];
  nativeBuildInputs = [
    pkgs.meson
    pkgs.cmake
    pkgs.fontconfig
    pkgs.ninja
    pkgs.pkg-config
  ];
  buildInputs = [
    faust
    pkgs.lv2
  ];
  preConfigure = ''
    substituteInPlace src/mephisto.c \
      --replace-fail 'faust -dspdir' 'echo ${faust.dsplibs}/share/faust'
  '';
  mesonBuildType = "minsize";
}
