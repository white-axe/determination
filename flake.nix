# Determination - Deterministic rendering environment for music and art
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-23.11";
    unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };
  outputs = { self, nixpkgs, unstable }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      pkgsUnstable = import unstable { inherit system; };
      config = import ./config.nix;
      raw = pkgs.buildEnv {
        name = "determination";
        paths = [
          ./stuff
          pkgs.bashInteractive
          pkgs.coreutils
        ] ++ pkgs.lib.optionals config.krita [
          (pkgs.callPackage ./krita.nix { })
          (pkgs.callPackage ./zopfli.nix { })
        ] ++ pkgs.lib.optionals config.ardour [
          (pkgs.callPackage ./ardour.nix { })
          pkgs.ffmpeg
          pkgs.flac
          pkgs.gawk
        ] ++ pkgs.lib.optionals config.ffmpeg [
          pkgs.ffmpeg
        ] ++ pkgs.lib.optionals config.flac [
          pkgs.flac
        ] ++ pkgs.lib.optionals config.exiftool [
          pkgs.exiftool
        ] ++ pkgs.lib.optionals config.zopfli [
          (pkgs.callPackage ./zopfli.nix { })
        ] ++ pkgs.lib.optionals (config.ardour && config.zynaddsubfx) [
          (pkgs.callPackage ./zynaddsubfx.nix { })
        ];
        pathsToLink = [
          "/bin"
        ] ++ pkgs.lib.optionals config.ardour [
          "/lib/lv2"
          "/root/.config/ardour8"
        ];
      };
      container = pkgs.stdenvNoCC.mkDerivation {
        name = "container-image-determination";
        src = pkgs.dockerTools.buildImage {
          name = "determination";
          tag = "latest";
          copyToRoot = raw;
          runAsRoot = ''
            ${pkgs.dockerTools.shadowSetup}
          '' + pkgs.lib.optionalString (!config.krita) ''
            rm -f /bin/determination-krita-*
            rm -f /bin/.determination-krita-*
          '' + pkgs.lib.optionalString (!config.ardour) ''
            rm -f /bin/determination-ardour-*
            rm -f /bin/.determination-ardour-*
          '';
          #compressor = "zstd";
          config = {
            Cmd = [ "/bin/bash" ];
          };
        };
        buildInputs = [
          pkgs.jq
          pkgs.skopeo
        ];
        unpackPhase = ":";
        buildPhase = ''
          skopeo --debug --insecure-policy --tmpdir="$TMPDIR" copy -f oci --dest-compress-format zstd --dest-compress-level 20 docker-archive:"$src" oci-archive:image.tar
          mkdir image
          tar -C image -xf image.tar
          rm image.tar
          cd image
          digests=$(jq -er '.manifests[].digest' < index.json)
          i=0
          for digest in $digests; do
            digest=''${digest#*:}
            cd blobs/sha256
            jq -c ".annotations += { \"org.opencontainers.image.description\": \"Deterministic rendering environment for white-axe's music and art\", \"org.opencontainers.image.licenses\": \"GPL-3.0-only\", \"org.opencontainers.image.source\": \"https://github.com/white-axe/determination\", \"org.opencontainers.image.title\": \"Determination\" }" < $digest > $digest.out && mv $digest.out $digest
            new_size=$(wc -c < $digest)
            new_digest=$(sha256sum $digest | awk '{print $1}')
            mv $digest $new_digest
            cd ../..
            jq -c ".manifests[$i] += { digest: \"sha256:$new_digest\", size: $new_size }" < index.json > index.json.out && mv index.json.out index.json
            ((++i))
          done
          cd ..
        '';
        installPhase = ''
          cd image
          LC_ALL=C tar --sort=name --format=posix --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime -cf "$out" *
        '';
      };
    in {
      packages.${system} = {
        default = container;
        container = container;
        raw = raw;
        skopeo = pkgsUnstable.skopeo;
        tar = pkgs.gnutar;
        zstd = pkgs.zstd;
      };
    };
}
