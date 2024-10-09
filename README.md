# Abstract

If you're a software developer, you may have heard of reproducible builds. I think it's important to consider extending binary reproducibility to things other than software.

The problem with many synthesizer plugins and effects plugins commonly used in music production is that they depend on global state in some way. For example, if a synthesizer has a white noise generator, it'll need some source of randomness that may be very hard to get exactly the same on two different renderings of the audio. Another example is if an effect uses low-frequency oscillators (LFO): the phase of a low-frequency oscillator often depends on how much time has passed since the plugin was initialized, which also can be really hard to control.

This is an [OCI container image](https://opencontainers.org) that can reproducibly render my music from the project files, which are designed for the [Carla](https://github.com/falkTX/Carla) audio plugin host. Every time you use this container image to render my music, even on different computers, the output files should be the same. The image is for x86-64 computers, but it should be runnable on other architectures using [QEMU](https://www.qemu.org) without affecting reproducibility of the output files.

It comes with the following LV2 audio plugins, modified to behave deterministically.

* [Mephisto](https://git.open-music-kontrollers.ch/~hp/mephisto.lv2), an LV2 plugin that allows you to design your own synthesizers and effects in the [Faust](https://github.com/grame-cncm/faust) programming language and then runs them using LLVM just-in-time compilation.
* [Moony](https://git.open-music-kontrollers.ch/~hp/moony.lv2), an LV2 plugin that allows you to manipulate MIDI events and plugin parameters in the Lua programming language.
* [ZynAddSubFX](https://github.com/zynaddsubfx/zynaddsubfx), a software synthesizer, installed as an LV2 plugin.

# Usage

Install either [Docker](https://www.docker.com) or [Podman](https://podman.io). If you're using Windows or macOS, I recommend using Podman instead of Docker because the Windows and macOS versions of Docker are proprietary software covered by a restrictive licensing agreement. If you're on Linux, please note that Docker Desktop and Docker Engine (the latter of which is also known as "docker.io" or "Docker CE") are not the same thing, and that only Docker Engine is free and open-source software.

Then run this command from a terminal, replacing `<path>` with the absolute path on your computer of a project directory. You may need to run the command as root, or as administrator on Windows. If you're using Podman, also replace `docker` with `podman` in the command.

```
docker run --rm -it --shm-size 256m --network none -v <path>:/data ghcr.io/white-axe/determination
```

This downloads the image, uses it to create a new container with the project directory mounted at `/data` in the container, and connects you to a Bash shell inside the container. You can also add a `:` and a version after the `ghcr.io/white-axe/determination` if you want a specific version of the image, e.g. `ghcr.io/white-axe/determination:2` for the latest version with a major version number of 2.

Inside of the container, the command `determination-export` is provided for rendering Carla patchbay projects. Assuming the .carxp file is named "project.carxp", you can run `determination-export /data/project.carxp -o /data/project.flac` to export the first 10 minutes of the project as audio. Run `determination-export --help` for more detailed usage instructions.

# Building the image from source

These are the instructions for building the container image from the source code in this repository. You don't need to do this if you just want to use the container image.

The image is designed to build reproducibly: every time you build the image, regardless of the computer it's built on or when it's built, the resulting image tar archive should be identical.

Install the [Nix package manager](https://nixos.org) on an x86-64 Linux computer and run the following commands to build the container image. The minimum supported version of Nix is 2.8.0. You must have [sandboxing](https://nixos.wiki/wiki/Nix_package_manager#Sandboxing) enabled or the build will not be reproducible. If you don't have an x86-64 computer, you can use [QEMU](https://www.qemu.org) to emulate an x86-64 Linux system and install Nix in there without compromising build reproducibility.

```
git clone https://github.com/white-axe/determination
cd determination
nix --experimental-features 'nix-command flakes' build
```

This creates an uncompressed tar archive named "result" with no file extension. Import it into Podman using `podman load -i result` on a computer that has Podman installed. To import it into Docker, install [Skopeo](https://github.com/containers/skopeo) and then run `skopeo copy oci-archive:result docker-archive:result-converted` to convert the tar archive to Docker's format before importing it with `docker load -i result-converted`. You may need to run the `podman load` or `docker load` command as root or administrator.

If you modify the contents of this repository, keep in mind that Nix ignores untracked files in Git, so always use `git add` to add untracked files before building.

By default, the image will be built using some cached binaries from Nix's binary cache. To disable the binary cache, add `--option substitute false` to the `nix` command, which will cause all source files to be fetched from their respective project websites and then build everything from source.

In case any of these project websites and/or the Nix cache are suffering from link rot, each release on GitHub also comes with a closure that contains the source code of everything you need to build this image offline aside from Nix itself. Because GitHub has a file size limit for releases, some releases' closures may be distributed in parts which must be concatenated together before extracting.

The closures are also designed to be reproducible. A script, "close.sh", is provided for building closures on x86-64 Linux computers so you can verify the reproducibility of the closures.

# Legal

The compiled image and the source files in this repository are licensed under the [GNU General Public License v3.0 or later](https://www.gnu.org/licenses/gpl-3.0.en.html) for license compatibility with some of the similarly-licensed software that is included in this image.

Most of the Nix packages in the source code of this image are based on the ones from the [release-24.05 branch of the Nixpkgs repository](https://github.com/NixOS/nixpkgs/tree/release-24.05). Their license can be found [here](https://github.com/NixOS/nixpkgs/blob/release-24.05/COPYING).

Links to all the source code for all of the other third-party software included in this image and used for building this image, their licenses, as well as the patch files used when building them that are not included in this repository, are available in the [release-24.05 branch of the Nixpkgs repository](https://github.com/NixOS/nixpkgs/tree/release-24.05). They are also available in the closures distributed with each release of this image on GitHub.
