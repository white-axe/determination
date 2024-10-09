#!/bin/bash
# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

set -eEo pipefail

alias nix="nix --experimental-features 'nix-command flakes'"

nix build '.#jq' -Lo 'closure-determination-jq'
nix build '.#tar' -Lo 'closure-determination-tar'
nix build '.#zstd' -Lo 'closure-determination-zstd'

paths=

image_derivation="$(nix derivation show | ./closure-determination-jq-bin/bin/jq -er 'keys_unsorted[0]')"
formatter_derivation="$(nix derivation show '.#formatter' | ./closure-determination-jq-bin/bin/jq -er 'keys_unsorted[0]')"

for derivation in $(nix derivation show -r | ./closure-determination-jq-bin/bin/jq -er 'map_values(select(.env.urls or .env.url)) | keys[]'); do
  echo -e "\e[96mBuilding source derivation $derivation\e[0m"
  paths+="$derivation"$'\n'
  paths+="$(nix build "$derivation^*" --print-out-paths)"$'\n'
done

for derivation in $(nix derivation show -r '.#formatter' | ./closure-determination-jq-bin/bin/jq -er 'map_values(select(.env.urls or .env.url)) | keys[]'); do
  echo -e "\e[96mBuilding source derivation $derivation\e[0m"
  paths+="$derivation"$'\n'
  paths+="$(nix build "$derivation^*" --print-out-paths)"$'\n'
done

if [ -e closure-determination ]; then
  chown -R $(id -u):$(id -g) closure-determination
  chmod -R +w closure-determination
  rm -r closure-determination/
fi
nix copy --to ./closure-determination "$image_derivation" --no-check-sigs
nix copy --to ./closure-determination "$formatter_derivation" --no-check-sigs

chown -R $(id -u):$(id -g) closure-determination/nix/var/
chmod -R +w closure-determination/nix/var/
rm -r closure-determination/nix/var/
chown -R $(id -u):$(id -g) closure-determination/nix/store/.links/
chmod -R +w closure-determination/nix/store/.links/
rm -r closure-determination/nix/store/.links/

for src in $paths; do
  if [ -e "$src" ]; then
    dst="closure-determination/nix/store/$(basename "$src")"
    if [ ! -e "$dst" ]; then
      echo -e "\e[96mCopying $src to $dst\e[0m"
      cp -r "$src" "$dst"
    fi
  fi
done

cd closure-determination

size=$(LC_ALL=C ../closure-determination-tar/bin/tar --sort=name --format=posix --mtime='@1' --owner=0 --group=0 --numeric-owner --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime -cf - * | wc -c)
echo "Tarball without compression will be $size bytes large"
LC_ALL=C ../closure-determination-tar/bin/tar --sort=name --format=posix --mtime='@1' --owner=0 --group=0 --numeric-owner --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime -cf - * | ../closure-determination-zstd-bin/bin/zstd --stream-size=$size -T0 --ultra -20 > ../closure-determination.tar.zst

cd ..

chown -R $(id -u):$(id -g) closure-determination
chmod -R +w closure-determination
rm -r closure-determination/
rm closure-determination-jq-bin
rm closure-determination-tar
rm closure-determination-zstd-bin

echo -e '\e[96mDone!\e[0m'
