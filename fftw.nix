# Determination - Deterministic rendering environment for music and art
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
{ pkgs }:
let
  version = "3.3.10";
in
pkgs.stdenv.mkDerivation {
  name = "fftw";
  inherit version;
  src = pkgs.fetchurl {
    urls = [
      "https://fftw.org/fftw-${version}.tar.gz"
      "ftp://ftp.fftw.org/pub/fftw/fftw-${version}.tar.gz"
    ];
    hash = "sha256-VskyVJhSzdz6/as4ILAgDHdCZ1vpIXnlnmIVs0DiZGc=";
  };
  patches = [
    (pkgs.fetchpatch {
      name = "remove_missing_FFTW3LibraryDepends.patch";
      url = "https://github.com/FFTW/fftw3/pull/338/commits/f69fef7aa546d4477a2a3fd7f13fa8b2f6c54af7.patch";
      hash = "sha256-lzX9kAHDMY4A3Td8necXwYLcN6j8Wcegi3A7OIECKeU=";
    })
  ];
  configureFlags = [
    "--enable-single"
    "--enable-threads"
    "--disable-doc"
  ];
  postPatch = ''
    substituteInPlace configure --replace "-mtune=native" "-mtune=generic"
  '';
}
