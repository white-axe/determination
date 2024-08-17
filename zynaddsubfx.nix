# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
let
  version = "3.0.6";
in
pkgs.stdenv.mkDerivation {
  pname = "zynaddsubfx";
  inherit version;
  src = pkgs.fetchFromGitHub {
    owner = "zynaddsubfx";
    repo = "zynaddsubfx";
    rev = version;
    fetchSubmodules = true;
    hash = "sha256-0siAx141DZx39facXWmKbsi0rHBNpobApTdey07EcXg=";
  };
  patches = [
    ./zynaddsubfx-fix-compilation-errors.patch
    ./zynaddsubfx-disable-executable.patch
    ./zynaddsubfx-disable-fpu-optimizations.patch
    ./zynaddsubfx-fix-dpf.patch
    ./zynaddsubfx-fix-slot-numbers.patch
    ./zynaddsubfx-sequential-pad.patch
    ./zynaddsubfx-thread-local-prng.patch
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
