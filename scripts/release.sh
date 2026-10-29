#!/usr/bin/env bash
# Cuts a release: updates pubspec.yaml, commits, and creates an annotated tag.
# Add the CHANGELOG.md section for the version before running this script.
#
# The version may match pubspec.yaml (for example when you are tagging a
# version that is already prepared); in that case only the tag is created.
#
# Usage:
#   scripts/release.sh 1.2.0          # commit and tag locally
#   scripts/release.sh 1.2.0 --push   # also push the commit and tag
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <major.minor.patch> [--push]" >&2
  exit 2
fi

version="$1"
push="${2:-}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must be semver, e.g. 1.2.0" >&2
  exit 1
fi

if [[ -n "$push" && "$push" != "--push" ]]; then
  echo "Unknown option: $push" >&2
  exit 2
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git repository." >&2
  exit 1
fi

if git rev-parse -q --verify "refs/tags/v$version" >/dev/null; then
  echo "Tag v$version already exists." >&2
  exit 1
fi

current_line="$(grep -E '^version:' pubspec.yaml || true)"
if [[ -z "$current_line" ]]; then
  echo "Could not read version from pubspec.yaml" >&2
  exit 1
fi

current_version="$(sed -E 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+).*/\1/' <<<"$current_line")"
current_build="$(sed -E 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+).*/\2/' <<<"$current_line")"
current_build="${current_build:-0}"
if [[ ! "$current_build" =~ ^[0-9]+$ ]]; then
  current_build=0
fi

same_version=0
if [[ "$version" == "$current_version" ]]; then
  same_version=1
fi

version_gt() {
  local old=$1 new=$2
  local IFS=.
  read -r old_major old_minor old_patch <<<"$old"
  read -r new_major new_minor new_patch <<<"$new"
  (( new_major > old_major ||
     (new_major == old_major && new_minor > old_minor) ||
     (new_major == old_major && new_minor == old_minor && new_patch > old_patch) ))
}

if (( same_version == 0 )) && ! version_gt "$current_version" "$version"; then
  echo "New version $version is lower than current $current_version." >&2
  exit 1
fi

if ! grep -qE "^## \[$version\]" CHANGELOG.md; then
  echo "Add a '## [$version] - YYYY-MM-DD' section to CHANGELOG.md first." >&2
  exit 1
fi

unexpected="$(git status --porcelain | cut -c4- | awk '$0 != "CHANGELOG.md" && $0 != "pubspec.yaml"')"
if [[ -n "$unexpected" ]]; then
  echo "Commit or stash unrelated changes first:" >&2
  printf '%s\n' "$unexpected" >&2
  exit 1
fi

if (( same_version == 0 )); then
  new_build=$((current_build + 1))
  sed -E "s/^version:.*/version: ${version}+${new_build}/" pubspec.yaml > pubspec.yaml.tmp
  mv pubspec.yaml.tmp pubspec.yaml
fi

git add pubspec.yaml CHANGELOG.md
if [[ -n "$(git diff --cached --name-only)" ]]; then
  git commit -m "release: v$version"
else
  echo "No version or changelog changes to commit; tagging the current commit."
fi
git tag -a "v$version" -m "v$version"
echo "Created tag v$version."

if [[ "$push" == "--push" ]]; then
  git push origin HEAD
  git push origin "v$version"
  echo "Pushed. The Release workflow will publish the APKs."
else
  echo "Push with:"
  echo "  git push origin HEAD --follow-tags"
fi
