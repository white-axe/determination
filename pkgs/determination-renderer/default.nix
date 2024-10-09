# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
let
  version = "2024-10-01";
  carla = pkgs.stdenv.mkDerivation {
    pname = "determination-renderer-carla-source";
    inherit version;
    src = pkgs.fetchFromGitHub {
      owner = "falkTX";
      repo = "Carla";
      rev = "e312817b6f3d95e928dfde119934e7657092e7cc";
      hash = "sha256-jznejvHl6+L0IHmbfSEkdk5vxWbueN9BVa+xl1NQQ4c=";
    };
    patches = [
      ./expose.patch
      ./jack-metadata.patch
      ./recorder.patch
      ./resource-dir-assert.patch
      ./rolling.patch
      ./static.patch
    ];
    buildPhase = ":";
    installPhase = ''
      cp -r "." "$out"
    '';
    fixupPhase = ":";
  };
in
pkgs.stdenv.mkDerivation {
  pname = "determination-renderer";
  version = "+carla-${version}";
  src = ./src;
  nativeBuildInputs = [
    pkgs.cmake
    pkgs.pkg-config
  ];
  buildInputs = [ (pkgs.callPackage ../jack2 { }) ];
  preConfigure = ''
    ln -s "${carla}" ./carla
  '';
  cmakeBuildType = "MinSizeRel";
  buildPhase = ''
    cmake --build . -t determination-renderer -j $NIX_BUILD_CORES
  '';
  installPhase = ''
    mkdir "$out"
    mkdir "$out/bin"
    cp determination-renderer "$out/bin/.determination-renderer"
  '';
}
