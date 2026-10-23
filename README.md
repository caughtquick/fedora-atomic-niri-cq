# fedora-atomic-niri-cq &nbsp; [![bluebuild build badge](https://github.com/caughtquick/fedora-atomic-niri-cq/actions/workflows/build.yml/badge.svg)](https://github.com/caughtquick/fedora-atomic-niri-cq/actions/workflows/build.yml)

This repository builds my personal Fedora Atomic image with [BlueBuild](https://blue-build.org/), based on `quay.io/fedora-ostree-desktops/sway-atomic`.

It is tailored to my setup and is not meant to be a general-purpose distro image.

## What this image is

- A Fedora Atomic image that swaps the default Sway session for **Niri**
- Configured to use **greetd** with **Noctalia Greeter** by default (SDDM kept as fallback)
- Includes my preferred core packages (for example: ghostty, distrobox, chezmoi, libvirt, gnome-keyring)
- Adds fingerprint authentication support and image signing policy for signed rebases

## Installation

> [!WARNING]  
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

To rebase an existing atomic Fedora installation to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies installed:
  ```
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/caughtquick/fedora-atomic-niri-cq:latest
  ```
- Reboot to complete the rebase:
  ```
  systemctl reboot
  ```
- Then rebase to the signed image, like so:
  ```
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/caughtquick/fedora-atomic-niri-cq:latest
  ```
- Reboot again to complete the installation
  ```
  systemctl reboot
  ```

The `latest` tag points to the most recent build from this repository. The Fedora major version is pinned by `recipes/recipe.yml`.

## ISO

If you build on Fedora Atomic, you can generate an offline ISO with the instructions [here](https://blue-build.org/how-to/generate-iso/#_top). Large ISO artifacts are not hosted in this repository.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/caughtquick/fedora-atomic-niri-cq
```
