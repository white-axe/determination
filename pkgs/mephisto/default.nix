# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
let
  version = "0.19.127";
  faust = pkgs.callPackage ../faust { };
  llvm = pkgs.callPackage ../llvm { };
in
pkgs.stdenv.mkDerivation {
  pname = "mephisto";
  inherit version;
  src = pkgs.fetchFromSourcehut {
    domain = "open-music-kontrollers.ch";
    owner = "~hp";
    repo = "mephisto.lv2";
    rev = "1201a260ef439873d6e2382c15b39ebc42c812e9";
    hash = "sha256-ad3nlWHvS8cqxFhgENLs+tFTWbVLTSqHtrJwVPlILVg=";
  };
  patches = [
    ./disable-ui.patch
    ./px.patch
    ./static.patch
    ./sync.patch
  ];
  nativeBuildInputs = [
    pkgs.meson
    pkgs.cmake
    pkgs.fontconfig
    pkgs.ninja
    pkgs.pkg-config
  ];
  buildInputs = [
    faust
    llvm
    pkgs.lv2
  ];
  preConfigure = ''
    libs=
    while IFS= read -r file; do
      libs="$libs,cc.find_library('$(basename "$file" | sed -e 's/^lib//' -e 's/\.a$//')')"
    done < <(find "${llvm}/lib" -maxdepth 1 -type f | sort)
    substituteInPlace src/mephisto.c \
      --replace-fail 'faust -dspdir' 'echo ${faust.dsplibs}/share/faust'
    substituteInPlace meson.build \
      --replace-fail 'dsp_deps = [m_dep, lv2_dep, faust_dep, varchunk_dep, timely_lv2_dep, props_lv2_dep]' "dsp_deps = [m_dep, lv2_dep, faust_dep $libs, varchunk_dep, timely_lv2_dep, props_lv2_dep]"
  '';
  mesonBuildType = "minsize";
}
