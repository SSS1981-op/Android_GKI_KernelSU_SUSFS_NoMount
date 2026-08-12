# Baseline definition

## Official source selection

This foundation follows AOSP's Android 14 common-kernel instructions. AOSP
documents `repo init -u https://android.googlesource.com/kernel/manifest -b
common-android14-6.1`, followed by the Kleaf GKI command:

```sh
tools/bazel run //common:kernel_aarch64_dist -- --destdir="$DIST_DIR"
```

The mutable branch names are used only to describe the upstream source line.
The build itself uses the immutable manifest and superproject commits in
[`../sources.lock.json`](../sources.lock.json). The superproject resolves every
project needed by the official manifest, including `kernel/common` and
`kernel/build`; the workflow confirms those two resolved commits explicitly.

References:

- <https://source.android.com/docs/setup/build/building-kernels>
- <https://source.android.com/docs/core/architecture/kernel/gki-android14-6_1-release-builds>
- <https://android.googlesource.com/kernel/manifest/+log/refs/heads/common-android14-6.1>

## Build and retention boundary

The official `kernel_aarch64_dist` target is used without source, config, or
device modifications. It can create the upstream distribution set, including
boot-related intermediates. This repository copies and uploads only
`DIST_DIR/Image`, which AOSP identifies as the kernel image binary. All other
distribution contents are represented only by a filename/size listing and are
not retained as workflow artifacts.

No release, signing, boot-image packing, vendor module integration, installation
command, or device target is part of this repository.

## Evidence and updates

Each successful manual build uploads a revision-pinned manifest, source
revisions, the locked inputs, official `gki_defconfig`, hashes, build logs, and
the retained Image hash. Do not put a successful build hash in this document
until that exact workflow run has completed successfully.

To advance the baseline, resolve and independently verify new immutable AOSP
manifest and superproject commits, update `sources.lock.json`, and run the
manual workflow. Keep the scope and artifact-retention rules unchanged.
