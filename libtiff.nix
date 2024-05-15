# Determination - Deterministic rendering environment for music and art
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
{ pkgs }:
let
  version = "4.6.0";
in
pkgs.stdenv.mkDerivation {
  pname = "libtiff";
  inherit version;
  src = pkgs.fetchFromGitLab {
    owner = "libtiff";
    repo = "libtiff";
    rev = "v${version}";
    hash = "sha256-qCg5qjsPPynCHIg0JsPJldwVdcYkI68zYmyNAKUCoyw=";
  };
  nativeBuildInputs = [
    pkgs.autoreconfHook
    pkgs.pkg-config
  ];
  buildInputs = [
    pkgs.boost
    pkgs.freetype
    pkgs.fontconfig
    pkgs.libiconv
    pkgs.libintl
  ];
}
