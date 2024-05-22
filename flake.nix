# Determination - Deterministic rendering environment for music and art
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-24.05";
  };
  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      config = import ./config.nix;
      builder = import ./builder.nix {
        inherit pkgs;
        imageName = "determination";
      };
      formatter = pkgs.nixfmt-rfc-style;
      image = builder.buildImage {
        architecture = "amd64";
        os = "linux";
        annotations = {
          "org.opencontainers.image.source" = "https://github.com/white-axe/determination";
          "org.opencontainers.image.licenses" = "GPL-3.0-only";
          "org.opencontainers.image.title" = "Determination";
          "org.opencontainers.image.description" = "Deterministic rendering environment for white-axe's music and art";
        };
        config = {
          Env = [ "PATH=/bin" ];
          Cmd = [ "/bin/bash" ];
        };
        layers =
          [
            {
              name = "base";
              paths = [
                pkgs.bashInteractive
                pkgs.coreutils
                pkgs.getopt
              ];
              runAsRoot = pkgs.dockerTools.shadowSetup;
            }
            {
              name = "tools";
              paths =
                pkgs.lib.optionals config.exiftool [ pkgs.exiftool ]
                ++ pkgs.lib.optionals config.ffmpeg [ pkgs.ffmpeg-headless ]
                ++ pkgs.lib.optionals config.flac [ pkgs.flac ]
                ++ pkgs.lib.optionals config.zopfli [ (pkgs.callPackage ./zopfli.nix { }) ];
            }
          ]
          ++ pkgs.lib.optionals config.krita [
            {
              name = "krita";
              paths = [
                (pkgs.callPackage ./krita.nix { })
                (pkgs.callPackage ./zopfli.nix { })
              ];
            }
          ]
          ++ pkgs.lib.optionals config.ardour [
            {
              name = "ardour";
              paths = [
                (pkgs.callPackage ./ardour.nix { })
                pkgs.ffmpeg-headless
                pkgs.flac
                pkgs.gawk
              ];
            }
          ]
          ++ pkgs.lib.optionals (config.ardour && config.zynaddsubfx) [
            {
              name = "zynaddsubfx";
              paths = [ (pkgs.callPackage ./zynaddsubfx.nix { }) ];
              pathsToLink = [ "/lib/lv2" ];
            }
          ]
          ++ [
            {
              name = "stuff";
              paths = [ ./stuff ];
              runAsRoot =
                pkgs.lib.optionalString (!config.krita) ''
                  rm -f /bin/determination-krita-*
                  rm -f /bin/.determination-krita-*
                ''
                + pkgs.lib.optionalString (!config.ardour) ''
                  rm -f /bin/determination-ardour-*
                  rm -f /bin/.determination-ardour-*
                '';
              pathsToLink = [ "/root/.config/ardour8" ];
            }
          ];
      };
    in
    {
      formatter.${system} = formatter;
      packages.${system} = {
        default = image;
        inherit image formatter;
        skopeo = pkgs.skopeo;
        tar = pkgs.gnutar;
        zstd = pkgs.zstd;
      };
    };
}
