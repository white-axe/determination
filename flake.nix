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
      formatter = pkgsUnstable.nixfmt-rfc-style;
      name = "determination";
      raw = pkgs.buildEnv {
        inherit name;
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
      baseJson = pkgs.writeText "${name}-dummy-config.json" "{}";
      layer = pkgs.dockerTools.mkRootLayer {
        inherit name baseJson;
        copyToRoot = raw;
        runAsRoot =
          pkgs.dockerTools.shadowSetup
          + pkgs.lib.optionalString (!config.krita) ''
            rm -f /bin/determination-krita-*
            rm -f /bin/.determination-krita-*
          ''
          + pkgs.lib.optionalString (!config.ardour) ''
            rm -f /bin/determination-ardour-*
            rm -f /bin/.determination-ardour-*
          '';
      };
      container =
        pkgs.runCommand "container-image-${name}.tar"
          {
            nativeBuildInputs = [
              pkgs.jq
              pkgs.libarchive
              pkgs.zstd
            ];
            closure = pkgs.writeReferencesToFile layer;
            config = pkgs.writeText "${name}-config.json" (builtins.toJSON { Cmd = [ "/bin/bash" ]; });
            annotations = pkgs.writeText "${name}-annotations.json" (
              builtins.toJSON {
                "org.opencontainers.image.source" = "https://github.com/white-axe/determination";
                "org.opencontainers.image.licenses" = "GPL-3.0-only";
                "org.opencontainers.image.title" = "Determination";
                "org.opencontainers.image.description" = "Deterministic rendering environment for white-axe's music and art";
              }
            );
          }
          ''
            ls_tar() {
              for f in $(tar -tf $1 | xargs realpath -ms --relative-to=.); do
                if [[ "$f" != "." ]]; then
                  echo "/$f"
                fi
              done
            }

            mkdir image
            cd image
            echo "{\"imageLayoutVersion\":\"1.0.0\"}" > oci-layout
            mkdir -p blobs/sha256
            cd blobs/sha256

            echo 'Converting layer to pax format...'
            bsdtar --format=pax -cf layer.tar @"${layer}"/layer.tar

            echo 'Copying layer closure to layer...'
            ls_tar layer.tar >> baseFiles
            for dep in $(cat "$closure"); do
              find "$dep" >> layerFiles
            done
            mkdir nix
            mkdir nix/store
            chmod -R 555 nix/
            echo './nix' >> layerFiles
            echo './nix/store' >> layerFiles
            comm <(sort -n baseFiles|uniq) <(sort -n layerFiles|uniq|grep -v ${layer}) -1 -3 > newFiles
            LC_ALL=C tar --hard-dereference --sort=name --format=posix --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime --no-recursion --verbatim-files-from --files-from newFiles -rpf layer.tar
            chmod -R 755 nix/
            rm -r nix/
            rm newFiles
            rm layerFiles
            rm baseFiles
            layer_diff_id=$(sha256sum layer.tar | awk '{print $1}')
            echo "Layer DiffID: sha256:$layer_diff_id"
            echo "Layer decompressed size: $(wc -c < layer.tar)"

            echo "Compressing layer with \`zstd -T$NIX_BUILD_CORES --ultra -20 layer.tar\`..."
            zstd -T$NIX_BUILD_CORES --ultra -20 layer.tar
            rm layer.tar
            layer_digest=$(sha256sum layer.tar.zst | awk '{print $1}')
            echo "Layer digest: sha256:$layer_digest"
            layer_size=$(wc -c < layer.tar.zst)
            echo "Layer size: $layer_size"
            mv layer.tar.zst $layer_digest

            echo 'Creating config...'
            jq -c "{ architecture: \"amd64\", os: \"linux\", config: ., rootfs: { type: \"layers\", diff_ids: [\"sha256:$layer_diff_id\"] } }" "$config" > config.json
            cat config.json
            config_digest=$(sha256sum config.json | awk '{print $1}')
            echo "Config digest: sha256:$config_digest"
            config_size=$(wc -c < config.json)
            echo "Config size: $config_size"
            mv config.json $config_digest

            echo 'Creating manifest...'
            jq -c "{ schemaVersion: 2, mediaType: \"application/vnd.oci.image.manifest.v1+json\", config: { mediaType: \"application/vnd.oci.image.config.v1+json\", digest: \"sha256:$config_digest\", size: $config_size }, layers: [{ mediaType: \"application/vnd.oci.image.layer.v1.tar+zstd\", digest: \"sha256:$layer_digest\", size: $layer_size }], annotations: . }" "$annotations" > manifest.json
            cat manifest.json
            manifest_digest=$(sha256sum manifest.json | awk '{print $1}')
            echo "Manifest digest: sha256:$manifest_digest"
            manifest_size=$(wc -c < manifest.json)
            echo "Manifest size: $manifest_size"
            mv manifest.json $manifest_digest

            cd ../..

            echo 'Creating index...'
            jq -c "{ schemaVersion: 2, manifests: [{ mediaType: \"application/vnd.oci.image.manifest.v1+json\", digest: \"sha256:$manifest_digest\", size: $manifest_size }] }" <(echo "{}") > index.json
            cat index.json

            echo 'Archiving...'
            LC_ALL=C tar --sort=name --format=posix --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime -cf "$out" *
          '';
    in
    {
      formatter.${system} = formatter;
      packages.${system} = {
        default = container;
        inherit container formatter raw;
        skopeo = pkgsUnstable.skopeo;
        tar = pkgs.gnutar;
        zstd = pkgs.zstd;
      };
    };
}
