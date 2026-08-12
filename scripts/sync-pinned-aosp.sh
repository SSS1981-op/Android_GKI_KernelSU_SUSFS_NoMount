#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <kernel-root> <sources-lock.json> <evidence-dir>" >&2
  exit 64
fi

kernel_root=$1
lock_file=$2
evidence_dir=$3

for command in git jq python3; do
  command -v "$command" >/dev/null || {
    echo "required command is unavailable: $command" >&2
    exit 69
  }
done

[[ -f "$lock_file" ]] || {
  echo "lock file not found: $lock_file" >&2
  exit 66
}
[[ ! -e "$kernel_root" ]] || {
  echo "kernel root must not already exist: $kernel_root" >&2
  exit 73
}

read_lock() {
  jq -er "$1" "$lock_file"
}

require_sha() {
  [[ "$2" =~ ^[0-9a-f]{40}$ ]] || {
    echo "invalid immutable revision for $1" >&2
    exit 65
  }
}

manifest_url=$(read_lock '.inputs.manifest.url')
manifest_commit=$(read_lock '.inputs.manifest.commit')
superproject_url=$(read_lock '.inputs.superproject.url')
superproject_commit=$(read_lock '.inputs.superproject.commit')
common_path=$(read_lock '.inputs.kernel_common.path')
common_commit=$(read_lock '.inputs.kernel_common.commit')
build_path=$(read_lock '.inputs.kernel_build.path')
build_commit=$(read_lock '.inputs.kernel_build.commit')
repo_tool_url=$(read_lock '.inputs.repo_tool.url')
repo_tool_commit=$(read_lock '.inputs.repo_tool.commit')

[[ "$manifest_url" == "https://android.googlesource.com/kernel/manifest" ]]
[[ "$superproject_url" == "https://android.googlesource.com/kernel/superproject" ]]
[[ "$repo_tool_url" == "https://gerrit.googlesource.com/git-repo" ]]
[[ "$common_path" == "common" ]]
[[ "$build_path" == "build/kernel" ]]
for name in manifest_commit superproject_commit common_commit build_commit repo_tool_commit; do
  require_sha "$name" "${!name}"
done

mkdir -p "$evidence_dir"
repo_root=$(dirname "$kernel_root")/.aosp-repo-client
[[ ! -e "$repo_root" ]] || {
  echo "repo client root must not already exist: $repo_root" >&2
  exit 73
}
# repo reuses its own checkout to bootstrap .repo/repo; it must be complete.
git clone --no-checkout "$repo_tool_url" "$repo_root"
git -C "$repo_root" checkout --detach "$repo_tool_commit"
[[ "$(git -C "$repo_root" rev-parse HEAD)" == "$repo_tool_commit" ]]

superproject_root=$(dirname "$kernel_root")/.aosp-superproject
[[ ! -e "$superproject_root" ]] || {
  echo "superproject root must not already exist: $superproject_root" >&2
  exit 73
}
git init "$superproject_root"
git -C "$superproject_root" fetch --depth=1 "$superproject_url" "$superproject_commit"
git -C "$superproject_root" cat-file -e "$superproject_commit^{commit}"

mkdir -p "$kernel_root"
pushd "$kernel_root" >/dev/null
"$repo_root/repo" init -u "$manifest_url" -b "$manifest_commit" --no-repo-verify
[[ "$(git -C .repo/manifests rev-parse HEAD)" == "$manifest_commit" ]]

python3 - "$superproject_root" "$superproject_commit" ".repo/manifests/default.xml" "$evidence_dir/materialized-manifest.xml" <<'PY'
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

superproject_root, commit, manifest_path, evidence_path = sys.argv[1:]
tree_data = subprocess.check_output(
    ["git", "-C", superproject_root, "ls-tree", "-r", "-z", commit]
)
gitlinks = {}
for entry in tree_data.split(b"\0"):
    if not entry:
        continue
    metadata, path = entry.split(b"\t", 1)
    mode, object_type, object_id = metadata.split()
    if mode == b"160000" and object_type == b"commit":
        gitlinks[path.decode("utf-8")] = object_id.decode("ascii")

tree = ET.parse(manifest_path)
root = tree.getroot()
superprojects = tree.findall("superproject")
if len(superprojects) != 1:
    raise SystemExit("expected exactly one superproject entry")
root.remove(superprojects[0])

for project in tree.findall("project"):
    project_path = project.get("path")
    if not project_path or project_path not in gitlinks:
        raise SystemExit(f"missing immutable superproject revision for {project_path!r}")
    project.set("revision", gitlinks[project_path])

ET.indent(tree, space="  ")
tree.write(manifest_path, encoding="UTF-8", xml_declaration=True)
shutil.copyfile(manifest_path, evidence_path)
PY

"$repo_root/repo" sync --no-use-superproject --no-clone-bundle --no-tags --optimized-fetch -j "${REPO_JOBS:-2}"
"$repo_root/repo" manifest -r -o "$evidence_dir/pinned-manifest.xml"

[[ "$(git -C "$common_path" rev-parse HEAD)" == "$common_commit" ]]
[[ "$(git -C "$build_path" rev-parse HEAD)" == "$build_commit" ]]
printf '%s\n' "$superproject_commit" > "$evidence_dir/superproject.commit"
git -C "$common_path" rev-parse HEAD > "$evidence_dir/kernel-common.commit"
git -C "$build_path" rev-parse HEAD > "$evidence_dir/kernel-build.commit"
cp "$lock_file" "$evidence_dir/sources.lock.json"

popd >/dev/null
