# Determination - Deterministic rendering environment for music and art
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
{ pkgs }:
let
  version = "5.2.2";
in
pkgs.stdenv.mkDerivation {
  pname = "krita";
  inherit version;
  src = pkgs.fetchurl {
    url = "mirror://kde/stable/krita/${version}/krita-${version}.tar.gz";
    hash = "sha256-wdLko219iqKW0CHlK+STzGedP+Xoqk/BPENNM+gVTOI=";
  };
  patches = [
    ./krita-disable-libmypaint.patch
    ./krita-disable-plugins.patch
    ./krita-disable-qt-quick.patch
    ./krita-disable-resource-bundle-warning.patch
    ./krita-enable-png-hdr.patch
    ./krita-unforce-platform.patch
  ];
  nativeBuildInputs = [
    pkgs.cmake
    pkgs.extra-cmake-modules
    pkgs.pkg-config
    pkgs.libsForQt5.wrapQtAppsHook
  ];
  buildInputs = [
    pkgs.boost
    pkgs.eigen
    pkgs.exiv2
    pkgs.fribidi
    pkgs.gsl
    pkgs.harfbuzz
    pkgs.immer
    pkgs.libsForQt5.kconfig
    pkgs.libsForQt5.kcompletion
    pkgs.libsForQt5.kcoreaddons
    pkgs.libsForQt5.kguiaddons
    pkgs.libsForQt5.ki18n
    pkgs.libsForQt5.kitemmodels
    pkgs.libsForQt5.kitemviews
    pkgs.kseexpr
    pkgs.libsForQt5.kwidgetsaddons
    pkgs.libsForQt5.kwindowsystem
    pkgs.lager
    (pkgs.callPackage ./lcms2.nix { })
    (pkgs.callPackage ./libtiff.nix { })
    pkgs.libunibreak
    pkgs.openexr
    (pkgs.callPackage ./poppler.nix { })
    pkgs.libsForQt5.qtbase
    pkgs.libsForQt5.qtx11extras
    pkgs.libsForQt5.quazip
    pkgs.zug
  ];
  cmakeBuildType = "RelWithDebInfo";
  cmakeFlags = [
    "-DKRITA_ENABLE_PCH=OFF" # Otherwise it takes like 30 GiB of space to build Krita
  ];
}
