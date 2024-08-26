# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
let
  version = "17.0.6";
in
pkgs.stdenv.mkDerivation {
  pname = "llvm";
  inherit version;
  src = pkgs.fetchFromGitHub {
    owner = "llvm";
    repo = "llvm-project";
    rev = "llvmorg-${version}";
    hash = "sha256-8MEDLLhocshmxoEBRSKlJ/GzJ8nfuzQ8qn0X/vLA+ag=";
  };
  nativeBuildInputs = [
    pkgs.cmake
    pkgs.python3
  ];
  preConfigure = ''
    cd llvm
  '';
  cmakeBuildType = "MinSizeRel";
  cmakeFlags = [
    "-DLLVM_TARGETS_TO_BUILD=host"
    "-DLLVM_INCLUDE_TOOLS=OFF"
    "-DLLVM_BUILD_TOOLS=OFF"
    "-DLLVM_INCLUDE_UTILS=OFF"
    "-DLLVM_BUILD_UTILS=OFF"
    "-DLLVM_INCLUDE_DOCS=OFF"
    "-DLLVM_BUILD_DOCS=OFF"
    "-DLLVM_INCLUDE_TESTS=OFF"
    "-DLLVM_BUILD_TESTS=OFF"
  ];
}
