# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
let
  version = "0.90.3";
in
pkgs.stdenv.mkDerivation {
  pname = "calf";
  inherit version;
  src = pkgs.fetchFromGitHub {
    owner = "calf-studio-gear";
    repo = "calf";
    rev = version;
    hash = "sha256-V2TY1xmV223cnc6CxaTuvLHqocVVIkQlbSI6Z0VTH00=";
  };
  patches = [
    ./fpu.patch
    ./thread-local-prng.patch
  ];
  nativeBuildInputs = [
    pkgs.autoreconfHook
    pkgs.pkg-config
  ];
  buildInputs = [
    pkgs.expat
    (pkgs.callPackage ../fftw { })
    (pkgs.callPackage ../fluidsynth { })
    pkgs.glib
    pkgs.lv2
  ];
  postPatch = ''
    # Replace all calls to `rand()` with `determination_rand()` and all calls to `srand()` with `determination_srand()`
    find src -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp' \) -exec bash -c "echo -e '\n#include <calf/determination_prng.h>\n' >> {} && sed -i 's/\b\(rand\|srand\)\b/determination_\1/g' {}" \;
  '';
  postInstall = ''
    rm -r "$out/share/doc"
    rm -r "$out/share/calf/styles"
  '';
}
