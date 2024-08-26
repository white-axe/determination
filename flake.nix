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
      builder = import ./builder.nix { inherit pkgs; };
      formatter = pkgs.nixfmt-rfc-style;
      image = builder.buildImage {
        imageName = "determination";
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
        excludePathRegex = "^${pkgs.glibc}/share/i18n/locales/[^C]|^${pkgs.bashInteractive}/share/locale/";
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
            name = "renderer";
            paths = [
              (pkgs.callPackage ./pkgs/determination-renderer { })
              pkgs.flac
              (pkgs.callPackage ./pkgs/jack2 { })
            ];
          }
          {
            name = "mephisto";
            paths = [ (pkgs.callPackage ./pkgs/mephisto { }) ];
            pathsToLink = [ "/lib/lv2" ];
          }
          {
            name = "zynaddsubfx";
            paths = [ (pkgs.callPackage ./pkgs/zynaddsubfx { }) ];
            pathsToLink = [ "/lib/lv2" ];
          }
          {
            name = "scripts";
            paths = [ (pkgs.callPackage ./pkgs/determination-export { }) ];
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
