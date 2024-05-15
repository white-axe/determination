# Determination - Deterministic rendering environment for music and art
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
{ pkgs }:
let
  version = "24.02.0";
in
pkgs.stdenv.mkDerivation {
  pname = "poppler";
  inherit version;
  src = pkgs.fetchurl {
    url = "https://poppler.freedesktop.org/poppler-${version}.tar.xz";
    hash = "sha256-GRh6P90F8z59YExHmcGD3lygEYZAyIs3DdzzE2NDIi4=";
  };
  nativeBuildInputs = [
    pkgs.cmake
    pkgs.ninja
    pkgs.pkg-config
    pkgs.python3
  ];
  buildInputs = [
    pkgs.boost
    pkgs.freetype
    pkgs.fontconfig
    pkgs.libiconv
    pkgs.libintl
  ];
  cmakeFlags = [
    "-DENABLE_DCTDECODER=none"
    "-DENABLE_GPGME=OFF"
    "-DENABLE_LCMS=OFF"
    "-DENABLE_LIBCURL=OFF"
    "-DENABLE_LIBOPENJPEG=none"
    "-DENABLE_LIBTIFF=OFF"
    "-DENABLE_NSS3=OFF"
    "-DENABLE_QT5=OFF"
    "-DENABLE_QT6=OFF"
  ];
}
