# Abstract

If you're a software developer, you may have heard of reproducible builds. I think it's important to consider extending binary reproducibility to things other than software.

This is an [OCI container image](https://opencontainers.org) that can reproducibly render my music and art from the project files. Every time you use this container image to render my music and art, even on different computers, the output files should be the same. Please make sure you run it on a computer with an x86-64 CPU, since floating-point arithmetic isn't portable across CPU architectures!

It comes with the following software, slimmed down and compiled without floating-point SIMD optimizations so that they behave exactly the same on most x86-64 CPUs.

* [Ardour](https://ardour.org), a digital audio workstation (DAW).
* [Krita](https://krita.org/en/), a 2D digital painting program.
* [ZynAddSubFX](https://zynaddsubfx.sourceforge.net), a software synthesizer, installed as an LV2 plugin. This particular image uses a fork I made with [a number of changes](https://github.com/zynaddsubfx/zynaddsubfx/compare/3.0.6..white-axe:zynaddsubfx:3.0.6-determinism0) to get rid of various other sources of nondeterminism.

# Usage

Install and initialize either [Docker](https://www.docker.com) or [Podman](https://podman.io). Docker Desktop is proprietary software with a restrictive license agreement, unlike the Linux-only free and open-source Docker Engine ("docker.io" or "Docker CE"), so if you're on Windows or macOS I recommend you use Podman CLI or Podman Desktop, both of which are free and open-source and available for Windows, macOS and Linux.

Then run this command from a terminal, replacing `<path>` with the absolute path on your computer of a project directory. You may need to run the command as root, or as administrator on Windows. If you're using Podman, also replace `docker` with `podman` in the command.

```
docker run --rm -it --network none -v <path>:/data ghcr.io/white-axe/determination
```

This downloads the image, uses it to create a new container with the project directory mounted at `/data` in the container, and connects you to a Bash shell inside the container. You can also add a `:` and a version after the `ghcr.io/white-axe/determination` if you want a specific version of the image, e.g. `ghcr.io/white-axe/determination:1` for the latest version with a major version number of 1.

Inside of the container, the command `determination-ardour-export` is provided for rendering Ardour projects. Assuming the .ardour file is named "session.ardour", you can run `determination-ardour-export -i /data/session.ardour` to export it as audio. Run `determination-ardour-export --help` for more detailed usage instructions. `determination-krita-export` is also provided with similar usage for rendering Krita projects.

# Building the image from source

These are the instructions for building the container image from the source code in this repository. You don't need to do this if you just want to use the container image.

Install the [Nix package manager](https://nixos.org) on an x86-64 Linux computer and run the following commands to build the container image. Docker isn't required to be installed to build the image.

```
git clone https://github.com/white-axe/determination
cd determination
nix --experimental-features 'nix-command flakes' build
```

Feel free also to edit config.nix before running the `nix` command to exclude components from the image that you don't need.

This creates a tarball named "result" with no file extension. Import it into Podman using `podman load -i result` on a computer that has Podman installed. To import it into Docker, install [Skopeo](https://github.com/containers/skopeo) and then run `skopeo copy oci-archive:result docker-archive:result-converted` to convert the tarball to Docker's format before importing it with `docker load -i result-converted`. You may need to run the `podman load` or `docker load` command as root or administrator.

If you modify the contents of this repository, keep in mind that Nix ignores untracked files in Git, so always use `git add` to add untracked files before building.

By default, the image will be built using some cached binaries from Nix's binary cache. To disable the binary cache, add `--option substitute false` to the `nix` command, which will cause all source files to be fetched from their respective project websites and then build everything from source. In case any of these project websites and/or the Nix cache are suffering from link rot, each release on GitHub also comes with a closure that contains the source code of everything you need to build this image offline aside from Nix itself. Because GitHub has a file size limit for releases, the closures are distributed in parts which must be concatenated together before extracting.

# Legal

The compiled image and the source files in this repository are licensed under the [GNU General Public License v3.0 only](https://www.gnu.org/licenses/gpl-3.0.en.html) for license compatibility with some of the similarly-licensed software that is included in this image.

Most of the Nix packages in the source code of this image are based on the ones from the [release-23.11 branch of the Nixpkgs repository](https://github.com/NixOS/nixpkgs/tree/release-23.11). Their license can be found [here](https://github.com/NixOS/nixpkgs/blob/release-23.11/COPYING).

Links to all the source code for all of the other third-party software included in this image and used for building this image, their licenses, as well as the patch files used when building them that are not included in this repository, are available in the [release-23.11 branch of the Nixpkgs repository](https://github.com/NixOS/nixpkgs/tree/release-23.11). They are also available in the closures distributed with each release of this image on GitHub.
