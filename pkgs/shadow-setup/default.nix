# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{ pkgs }:
let
  script = pkgs.writeText "shadow-setup.sh" pkgs.dockerTools.shadowSetup;
in
pkgs.runCommandLocal "shadow-setup" { } ''
  export OUT="$out"
  cp "${script}" ./shadow-setup.sh
  substituteInPlace shadow-setup.sh --replace-fail '/etc/' '"$OUT"/etc/'
  bash shadow-setup.sh
''
