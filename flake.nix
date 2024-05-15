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
  outputs =
    {
      self,
      nixpkgs,
      unstable,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      pkgsUnstable = import unstable { inherit system; };
      config = import ./config.nix;
      raw = pkgs.buildEnv {
        name = "determination";
        paths =
          [
            ./stuff
            pkgs.bashInteractive
            pkgs.coreutils
            pkgs.getopt
          ]
          ++ pkgs.lib.optionals config.krita [
            (pkgs.callPackage ./krita.nix { })
            (pkgs.callPackage ./zopfli.nix { })
          ]
          ++ pkgs.lib.optionals config.ardour [
            (pkgs.callPackage ./ardour.nix { })
            pkgs.ffmpeg
            pkgs.flac
            pkgs.gawk
          ]
          ++ pkgs.lib.optionals config.ffmpeg [ pkgs.ffmpeg ]
          ++ pkgs.lib.optionals config.flac [ pkgs.flac ]
          ++ pkgs.lib.optionals config.exiftool [ pkgs.exiftool ]
          ++ pkgs.lib.optionals config.zopfli [ (pkgs.callPackage ./zopfli.nix { }) ]
          ++ pkgs.lib.optionals (config.ardour && config.zynaddsubfx) [
            (pkgs.callPackage ./zynaddsubfx.nix { })
          ];
        pathsToLink =
          [ "/bin" ]
          ++ pkgs.lib.optionals config.ardour [
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
          runAsRoot =
            ''
              ${pkgs.dockerTools.shadowSetup}
            ''
            + pkgs.lib.optionalString (!config.krita) ''
              rm -f /bin/determination-krita-*
              rm -f /bin/.determination-krita-*
            ''
            + pkgs.lib.optionalString (!config.ardour) ''
              rm -f /bin/determination-ardour-*
              rm -f /bin/.determination-ardour-*
            '';
          #compressor = "zstd";
          config = {
            Cmd = [ "/bin/bash" ];
          };
        };
        nativeBuildInputs = [
          pkgs.jq
          pkgs.libarchive
          pkgs.skopeo
          pkgs.zstd
        ];
        unpackPhase = ":";
        buildPhase = ''
          skopeo --debug --insecure-policy --tmpdir="$TMPDIR" copy -f oci --dest-compress-format zstd docker-archive:"$src" oci-archive:image.tar
          mkdir image
          tar -C image -xf image.tar
          rm image.tar
          cd image
          manifest_digests=$(jq -er '.manifests[].digest' < index.json)
          i=0
          for manifest_digest in $manifest_digests; do  # Annotate every manifest
            manifest_digest=''${manifest_digest#*:}
            cd blobs/sha256
            mv $manifest_digest manifest.json
            jq -c ".annotations += { \"org.opencontainers.image.description\": \"Deterministic rendering environment for white-axe's music and art\", \"org.opencontainers.image.licenses\": \"GPL-3.0-only\", \"org.opencontainers.image.source\": \"https://github.com/white-axe/determination\", \"org.opencontainers.image.title\": \"Determination\" }" < manifest.json > manifest.json.out && mv manifest.json.out manifest.json
            config_digest=$(jq -er '.config.digest' < manifest.json)
            config_digest=''${config_digest#*:}
            mv $config_digest config.json
            layer_digests=$(jq -er ".layers | map(select(.mediaType == \"application/vnd.oci.image.layer.v1.tar+zstd\"))[].digest" < manifest.json)
            j=0
            for layer_digest in $layer_digests; do  # Convert every layer from GNU tar format to pax tar format
              echo "Decompressing layer $j from manifest $i..."
              layer_digest=''${layer_digest#*:}
              mv $layer_digest old-layer.tar.zst
              zstd -d old-layer.tar.zst
              rm old-layer.tar.zst
              echo "Re-encoding layer $j from manifest $i..."
              bsdtar --format=pax -cf layer.tar @old-layer.tar
              new_diff_id=$(sha256sum layer.tar | awk '{print $1}')
              rm old-layer.tar
              echo "Compressing layer $j from manifest $i..."
              zstd --ultra -20 layer.tar
              rm layer.tar
              echo "Updating config for manifest $i..."
              jq -c ".rootfs.diff_ids[$j] = \"sha256:$new_diff_id\"" < config.json > config.json.out && mv config.json.out config.json
              new_config_size=$(wc -c < config.json)
              new_config_digest=$(sha256sum config.json | awk '{print $1}')
              mv config.json $new_config_digest
              echo "Updating manifest $i..."
              jq -c ".config += { digest: \"sha256:$new_config_digest\", size: $new_config_size }" < manifest.json > manifest.json.out && mv manifest.json.out manifest.json
              new_layer_size=$(wc -c < layer.tar.zst)
              new_layer_digest=$(sha256sum layer.tar.zst | awk '{print $1}')
              mv layer.tar.zst $new_layer_digest
              jq -c ".layers[$j] += { digest: \"sha256:$new_layer_digest\", size: $new_layer_size }" < manifest.json > manifest.json.out && mv manifest.json.out manifest.json
              ((++j))
            done
            echo "Updating index.json..."
            new_manifest_size=$(wc -c < manifest.json)
            new_manifest_digest=$(sha256sum manifest.json | awk '{print $1}')
            mv manifest.json $new_manifest_digest
            cd ../..
            jq -c ".manifests[$i] += { digest: \"sha256:$new_manifest_digest\", size: $new_manifest_size }" < index.json > index.json.out && mv index.json.out index.json
            ((++i))
          done
          cd ..
        '';
        installPhase = ''
          cd image
          LC_ALL=C tar --sort=name --format=posix --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime -cf "$out" *
        '';
      };
    in
    {
      packages.${system} = {
        default = container;
        container = container;
        raw = raw;
        skopeo = pkgsUnstable.skopeo;
        tar = pkgs.gnutar;
        zstd = pkgs.zstd;
      };
      formatter.${system} = pkgsUnstable.nixfmt-rfc-style;
    };
}
