# Determination - Deterministic rendering environment for music and art
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
{ pkgs }:
let
  version = "3.0.6-determinism0";
in
pkgs.stdenv.mkDerivation {
  name = "zynaddsubfx";
  inherit version;
  src = pkgs.fetchFromGitHub {
    owner = "white-axe";
    repo = "zynaddsubfx";
    rev = version;
    fetchSubmodules = true;
    hash = "sha256-TWSwHpW2hZeQkkINN+IIot9CpIak9vawDCvR+Mk7514=";
  };
  patches = [
    ./zynaddsubfx-disable-executable.patch
    ./zynaddsubfx-fix-dpf.patch
    ./zynaddsubfx-fix-slot-numbers.patch
  ];
  nativeBuildInputs = [
    pkgs.cmake
    pkgs.makeWrapper
    pkgs.pkg-config
  ];
  buildInputs = [
    (pkgs.callPackage ./fftw.nix { })
    pkgs.liblo
    pkgs.minixml
    pkgs.zlib
  ];
  cmakeFlags = [
    "-DGuiModule=off"
    "-DOssEnable=OFF"
  ];
}
