# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
let
  version = "2.74.6";
  llvm = pkgs.callPackage ../llvm { };
  ncurses = pkgs.ncurses.override { enableStatic = true; };
in
pkgs.stdenv.mkDerivation {
  pname = "faust";
  inherit version;
  src = pkgs.fetchFromGitHub {
    owner = "grame-cncm";
    repo = "faust";
    rev = version;
    fetchSubmodules = true;
    hash = "sha256-0r7DjTrsNKZ5ZmWoA+Y9OXyJFUiUFZiPQb1skXXWYTw=";
  };
  patches = [ ./share.patch ];
  nativeBuildInputs = [
    pkgs.cmake
    pkgs.pkg-config
  ];
  buildInputs = [ llvm ];
  outputs = [
    "out"
    "dsplibs"
  ];
  preConfigure = ''
    # This part is from Nixpkgs's version of the Faust package
    cd build
    sed -i 's@LIBNCURSES_PATH ?= .*@LIBNCURSES_PATH ?= ${ncurses}/lib/libncurses.a@' Make.llvm.static
    substituteInPlace Make.llvm.static \
      --replace-fail 'mkdir -p $@ && cd $@ && ar -x ../../$<' 'mkdir -p $@ && cd $@ && ar -x ../source/build/lib/libfaust.a && cd ../source/build/'
    substituteInPlace Make.llvm.static \
      --replace-fail 'rm -rf $(TMP)' ' '

    # We don't build `llvm-config` in our version of the LLVM package, which is required by Faust's build system,
    # so here we manually calculate what the outputs of `llvm-config` should be and write them to the build scripts
    libs=
    while IFS= read -r file; do
      libs="$libs-l$(basename "$file" | sed -e 's/^lib//' -e 's/\.a$//') "
    done < <(find "${llvm}/lib" -maxdepth 1 -type f | sort)
    substituteInPlace misc/llvm.cmake \
      --replace-fail 'if (''${LC} STREQUAL LC-NOTFOUND)' 'if (FALSE)'
    substituteInPlace misc/llvm.cmake \
      --replace-fail ' ''${LLVM_CONFIG} --version ' ' echo ${llvm.version} '
    substituteInPlace misc/llvm.cmake \
      --replace-fail ' ''${LLVM_CONFIG} --includedir ' ' echo ${llvm}/include '
    substituteInPlace misc/llvm.cmake \
      --replace-fail ' ''${LLVM_CONFIG} --ldflags ' ' echo -L${llvm}/lib '
    substituteInPlace misc/llvm.cmake \
      --replace-fail ' ''${LLVM_CONFIG}  --libs ' " echo $libs"
    substituteInPlace misc/llvm.cmake \
      --replace-fail ' ''${LLVM_CONFIG}  --system-libs ' " echo -lrt -ldl -lm -lz -ltinfo -lxml2 "
  '';
  cmakeBuildType = "MinSizeRel";
  cmakeFlags = [
    "-DC_BACKEND=STATIC"
    "-DCPP_BACKEND=STATIC"
    "-DLLVM_BACKEND=STATIC"
    "-DINCLUDE_EXECUTABLE=OFF"
    "-DINCLUDE_STATIC=ON"
    "-DINCLUDE_DYNAMIC=OFF"
    "-DINCLUDE_OSC=OFF"
    "-DINCLUDE_HTTP=OFF"
    "-DOSCDYNAMIC=OFF"
    "-DHTTPDYNAMIC=OFF"
    "-DINCLUDE_ITP=OFF"
    "-DITPDYNAMIC=OFF"
    "-DSELF_CONTAINED_LIBRARY=ON"
  ];
  postFixup = ''
    mkdir "$dsplibs"
    mv "$out/share" "$dsplibs/"
  '';
}
