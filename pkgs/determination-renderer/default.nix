# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
let
  version = "2f7c9394134ad8479a7c9f236123ff365fa68e99"; # 2024-09-22
  carla = pkgs.stdenv.mkDerivation {
    pname = "determination-renderer-carla";
    inherit version;
    src = pkgs.fetchFromGitHub {
      owner = "falkTX";
      repo = "Carla";
      rev = version;
      hash = "sha256-XlOWPsMzpzayim+rfxxzWhpm0jA0z669zukR03zIqPA=";
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
  inherit version;
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
