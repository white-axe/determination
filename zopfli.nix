# Determination - Deterministic rendering environment for music and art
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
{ pkgs }:
let
  version = "ccf9f0588d4a4509cb1040310ec122243e670ee6"; # 2024-04-11
in
  pkgs.stdenv.mkDerivation {
    name = "zopfli";
    version = version;
    src = pkgs.fetchFromGitHub {
      owner = "google";
      repo = "zopfli";
      rev = version;
      hash = "sha256-M1H0Op/j0H079V50WHllUXMIVVtZmoc7s5h1b2/u3Zk=";
    };
    nativeBuildInputs = [
      pkgs.cmake
    ];
  }
