# Android 14 GKI compile-only foundation

This repository is a reproducible, **compile-only** foundation for the official
AOSP Android 14 GKI source line backed by `common-android14-6.1`. It is not a
device kernel project and contains no device targets.

## Scope and safety boundary

The only workflow is manually dispatched. It checks out the immutable official
AOSP snapshot recorded in [`sources.lock.json`](sources.lock.json), runs the
official Kleaf `//common:kernel_aarch64_dist` target, and preserves only the
non-flashable `Image` kernel binary plus provenance and configuration evidence.
It never creates a GitHub release, signing key, flash package, or installation
guide. Although the upstream target may create additional intermediate
artifacts, the workflow neither publishes nor retains them.

An `Image` from this repository is **not a universal flashable image**. This
repository claims no supported devices. Device onboarding must establish, at a
minimum:

- exact codename and firmware/Android version;
- GKI generation and KMI compatibility;
- required vendor modules and partition layout;
- AVB state and a device-specific, reviewed packaging process; and
- physical-device boot and smoke validation.

The intentionally empty [`devices.json`](devices.json) is the machine-readable
device registry.

## Reproducible inputs

The lock records an immutable manifest commit, an immutable kernel superproject
commit, and the resolved commits for `kernel/common`, `kernel/build`, and the
official `git-repo` client. The workflow verifies each value after sync and
uploads a fully revision-pinned `repo manifest -r` as build evidence.

The source/build process follows the AOSP documentation:

- [Build kernels](https://source.android.com/docs/setup/build/building-kernels)
- [Android 14 6.1 GKI release builds](https://source.android.com/docs/core/architecture/kernel/gki-android14-6_1-release-builds)
- [Generic Kernel Image overview](https://source.android.com/docs/core/architecture/kernel/generic-kernel-image)

See [`docs/BASELINE.md`](docs/BASELINE.md) for the exact build boundary,
evidence layout, and update procedure.

## Running the workflow

From GitHub, use **Actions → Compile Android 14 GKI (compile-only) → Run
workflow**. The workflow has a three-hour timeout, low sync/build parallelism,
disk and memory preflight checks, immutable-input validation, and concurrency
protection.

The uploaded `android14-gki-compile-evidence` artifact contains:

- `Image` and `image.sha256`;
- `pinned-manifest.xml`, source revisions, and lockfile copy;
- the official `gki_defconfig` and its SHA-256;
- the upstream distribution file listing; and
- the source/build command logs.

Only use the reported SHA-256 to identify a build artifact; it does not imply
device compatibility, bootability, certification, signing, or flashability.
