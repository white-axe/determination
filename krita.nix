# Determination - Deterministic rendering environment for music and art
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
{ pkgs }:
let
  version = "5.1.5";
in
  pkgs.stdenv.mkDerivation {
    name = "krita";
    version = version;
    src = pkgs.fetchurl {
      url = "mirror://kde/stable/krita/${version}/krita-${version}.tar.gz";
      hash = "sha256-HHdevvD3mammt0RAw9kGq5E8J1QbF37WIXBN5xTppNM=";
    };
    patches = [
      (pkgs.fetchpatch {
        name = "exiv2-0.28.patch";
        url = "https://gitlab.archlinux.org/archlinux/packaging/packages/krita/-/raw/acd9a818660e86b14a66fceac295c2bab318c671/exiv2-0.28.patch";
        hash = "sha256-iD2pyid513ThJVeotUlVDrwYANofnEiZmWINNUm/saw=";
      })
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
      pkgs.gsl
      pkgs.immer
      (pkgs.callPackage ./lcms2.nix { })
      (pkgs.callPackage ./libtiff.nix { })
      pkgs.libsForQt5.kconfig
      pkgs.libsForQt5.kcompletion
      pkgs.libsForQt5.kcoreaddons
      pkgs.libsForQt5.kguiaddons
      pkgs.libsForQt5.ki18n
      pkgs.libsForQt5.kitemmodels
      pkgs.libsForQt5.kitemviews
      #pkgs.kseexpr
      pkgs.libsForQt5.kwidgetsaddons
      pkgs.libsForQt5.kwindowsystem
      pkgs.openexr
      (pkgs.callPackage ./poppler.nix { })
      pkgs.libsForQt5.qtbase
      pkgs.libsForQt5.qtx11extras
      pkgs.libsForQt5.quazip
    ];
    cmakeBuildType = "RelWithDebInfo";
    cmakeFlags = [
      "-DKRITA_ENABLE_PCH=OFF" # Otherwise it takes like 30 GiB of space to build Krita
    ];
  }
