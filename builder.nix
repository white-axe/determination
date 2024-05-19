# Determination - Deterministic rendering environment for music and art
# Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
{ pkgs, imageName }:
let
  nul = pkgs.runCommandLocal "${imageName}-nul" { } ''
    mkdir $out
  '';

  mkLayer =
    {
      name,
      paths,
      pathsToLink ? [ ],
      runAsRoot ? null,
    }:
    let
      args = {
        name = "${imageName}-${name}";
        baseJson = pkgs.writeText "${imageName}-dummy-basejson.json" "{}";
        copyToRoot = pkgs.buildEnv {
          inherit paths;
          name = "container-env-${imageName}-${name}";
          pathsToLink = [ "/bin" ] ++ pathsToLink;
        };
      };
    in
    {
      inherit name;
      layer =
        if runAsRoot == null then
          pkgs.dockerTools.mkPureLayer args
        else
          pkgs.dockerTools.mkRootLayer (args // { inherit runAsRoot; });
    };

  cookLayer =
    prevOutput:
    { name, layer }:
    pkgs.runCommand "container-layer-${imageName}-${name}"
      {
        nativeBuildInputs = [
          pkgs.jq
          pkgs.libarchive
          pkgs.zstd
        ];
        closure = pkgs.writeClosure [ layer ];
      }
      ''
        ls_tar() {
          for f in $(tar -tf $1 | xargs realpath -ms --relative-to=.); do
            if [[ "$f" != "." ]]; then
              echo "/$f"
            fi
          done
        }

        mkdir $out
        echo ${name} > $out/name
        if [[ ${prevOutput} != ${nul} ]]; then
          ln -s ${prevOutput} $out/prevOutput
        fi

        echo 'Converting layer to pax format...'
        bsdtar --format=pax -cf layer.tar @${layer}/layer.tar

        echo 'Copying layer closure to layer...'
        if [[ ${prevOutput} != ${nul} ]]; then
          cp ${prevOutput}/files baseFiles
          chmod 644 baseFiles
        fi
        ls_tar layer.tar >> baseFiles
        for dep in $(< $closure); do
          find "$dep" >> layerFiles
        done
        mkdir nix
        mkdir nix/store
        chmod -R 555 nix/
        echo './nix' >> layerFiles
        echo './nix/store' >> layerFiles
        comm <(sort -n baseFiles | uniq) <(sort -n layerFiles | uniq | grep -v ${layer}) -1 -3 > newFiles
        tar --hard-dereference --sort=name --format=posix --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime --no-recursion --verbatim-files-from --files-from newFiles -rpf layer.tar
        chmod -R 755 nix/
        rm -r nix/
        rm newFiles
        rm layerFiles
        layer_diff_id=$(sha256sum layer.tar | awk '{print $1}')
        echo "Layer DiffID: sha256:$layer_diff_id"
        echo "Layer decompressed size: $(wc -c < layer.tar)"
        echo $layer_diff_id > $out/diffId
        ls_tar layer.tar >> baseFiles
        sort -n baseFiles | uniq > $out/files
        rm baseFiles

        echo "Compressing layer with \`zstd -T$NIX_BUILD_CORES --ultra -20 layer.tar\`..."
        zstd -T$NIX_BUILD_CORES --ultra -20 layer.tar
        rm layer.tar
        layer_digest=$(sha256sum layer.tar.zst | awk '{print $1}')
        echo "Layer digest: sha256:$layer_digest"
        layer_size=$(wc -c < layer.tar.zst)
        echo "Layer size: $layer_size"
        mv layer.tar.zst $out/

        echo 'Done!'
      '';
in
{
  buildImage =
    {
      layers,
      architecture,
      os,
      config,
      annotations,
    }:
    pkgs.runCommand "container-image-${imageName}.tar"
      {
        nativeBuildInputs = [ pkgs.jq ];
        layers = pkgs.lib.foldl cookLayer nul (builtins.map mkLayer layers);
        config = pkgs.writeText "${imageName}-config.json" (builtins.toJSON config);
        annotations = pkgs.writeText "${imageName}-annotations.json" (builtins.toJSON annotations);
      }
      ''
        mkdir image
        cd image
        echo "{\"imageLayoutVersion\":\"1.0.0\"}" > oci-layout
        mkdir -p blobs/sha256
        cd blobs/sha256

        jq -c "{ architecture: \"${architecture}\", os: \"${os}\", config: ., rootfs: { type: \"layers\", diff_ids: [] } }" $config > config.json
        jq -c "{ schemaVersion: 2, mediaType: \"application/vnd.oci.image.manifest.v1+json\", config: { mediaType: \"application/vnd.oci.image.config.v1+json\" }, layers: [], annotations: . }" $annotations > manifest.json

        touch layerRefs
        if [[ -e $layers/prevOutput ]]; then
          while true; do
            realpath $layers >> layerRefs
            [[ -e $layers/prevOutput ]] || break
            layers=$(realpath $layers/prevOutput)
          done
        fi
        tac layerRefs > layerRefs.out && mv layerRefs.out layerRefs

        while read layer; do
          echo "Adding layer $(< $layer/name)..."
          layer_diff_id=$(< $layer/diffId)
          layer_digest=$(sha256sum $layer/layer.tar.zst | awk '{print $1}')
          layer_size=$(wc -c < $layer/layer.tar.zst)
          cp $layer/layer.tar.zst $layer_digest
          chmod 644 $layer_digest
          jq -c ".rootfs.diff_ids += [\"sha256:$layer_diff_id\"]" config.json > config.json.out && mv config.json.out config.json
          jq -c ".layers += [{ mediaType: \"application/vnd.oci.image.layer.v1.tar+zstd\", digest: \"sha256:$layer_digest\", size: $layer_size }]" manifest.json > manifest.json.out && mv manifest.json.out manifest.json
        done < layerRefs
        rm layerRefs

        echo 'Creating config...'
        cat config.json
        config_digest=$(sha256sum config.json | awk '{print $1}')
        echo "Config digest: sha256:$config_digest"
        config_size=$(wc -c < config.json)
        echo "Config size: $config_size"
        mv config.json $config_digest

        echo 'Creating manifest...'
        jq -c ".config += { digest: \"sha256:$config_digest\", size: $config_size }" manifest.json > manifest.json.out && mv manifest.json.out manifest.json
        cat manifest.json
        manifest_digest=$(sha256sum manifest.json | awk '{print $1}')
        echo "Manifest digest: sha256:$manifest_digest"
        manifest_size=$(wc -c < manifest.json)
        echo "Manifest size: $manifest_size"
        mv manifest.json $manifest_digest

        cd ../..

        echo 'Creating index...'
        echo '{}' | jq -c "{ schemaVersion: 2, manifests: [{ mediaType: \"application/vnd.oci.image.manifest.v1+json\", digest: \"sha256:$manifest_digest\", size: $manifest_size }] }" > index.json
        cat index.json

        echo 'Archiving...'
        tar --sort=name --format=posix --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime -cf $out *

        echo 'Done!'
      '';
}
