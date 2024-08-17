# Determination - Deterministic rendering environment for white-axe's music
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-24.05";
  };
  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            vmTools = prev.vmTools // {
              runInLinuxVM =
                drv:
                prev.lib.overrideDerivation (prev.vmTools.runInLinuxVM drv) (oldAttrs: {
                  requiredSystemFeatures = prev.lib.remove "kvm" oldAttrs.requiredSystemFeatures;
                });
            };
          })
        ];
      };
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
          "org.opencontainers.image.licenses" = "GPL-3.0-or-later";
          "org.opencontainers.image.title" = "Determination";
          "org.opencontainers.image.description" = "Deterministic rendering environment for white-axe's music";
        };
        config = {
          Env = [ "PATH=/bin" ];
          Cmd = [ "/bin/bash" ];
        };
        layers = [
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
            name = "flac";
            paths = [ pkgs.flac ];
          }
          {
            name = "renderer";
            paths = [
              (pkgs.callPackage ./determination-renderer.nix { })
              (pkgs.callPackage ./jack2.nix { })
            ];
          }
          {
            name = "zynaddsubfx";
            paths = [ (pkgs.callPackage ./zynaddsubfx.nix { }) ];
            pathsToLink = [ "/lib/lv2" ];
          }
          {
            name = "scripts";
            paths = [
              (pkgs.runCommandLocal "determination-export" { } ''
                mkdir "$out"
                mkdir "$out/bin"
                cp "${./determination-export}" "$out/bin/determination-export"
              '')
            ];
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
