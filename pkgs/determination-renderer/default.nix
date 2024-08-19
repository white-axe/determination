# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
let
  version = "948991d7b5104280c03960925908e589c77b169a"; # 2024-04-21
  carla = pkgs.stdenv.mkDerivation {
    pname = "determination-renderer-carla";
    inherit version;
    src = pkgs.fetchFromGitHub {
      owner = "falkTX";
      repo = "Carla";
      rev = version;
      hash = "sha256-uGAuKheoMfP9hZXsw29ec+58dJM8wMuowe95QutzKBY=";
    };
    patches = [
      ./expose.patch
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
  cmakeFlags = [ "-DDETERMINATION_CARLA_PATH=${carla}" ];
  buildPhase = ''
    cmake --build . -t determination-renderer -j $NIX_BUILD_CORES
  '';
  installPhase = ''
    mkdir "$out"
    mkdir "$out/bin"
    cp determination-renderer "$out/bin/.determination-renderer"
  '';
}
