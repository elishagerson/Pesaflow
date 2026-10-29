#!/usr/bin/env bash
# Prints the CHANGELOG.md section for a version, without the heading.
# Usage: scripts/changelog-section.sh 1.2.0 > release_notes.md
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <version>" >&2
  exit 2
fi

version="$1"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
changelog="$root/CHANGELOG.md"

if [[ ! -f "$changelog" ]]; then
  echo "CHANGELOG.md not found at $changelog" >&2
  exit 1
fi

notes="$(
  awk -v ver="$version" '
    BEGIN { found = 0; n = 0 }
    index($0, "## [" ver "]") == 1 { found = 1; next }
    found && index($0, "## [") == 1 { exit }
    found { lines[++n] = $0 }
    END {
      start = 1
      while (start <= n && lines[start] ~ /^[[:space:]]*$/) start++
      end = n
      while (end >= start && lines[end] ~ /^[[:space:]]*$/) end--
      for (i = start; i <= end; i++) print lines[i]
    }
  ' "$changelog"
)"

if [[ -z "$notes" ]]; then
  echo "No CHANGELOG.md section found for $version" >&2
  exit 1
fi

printf '%s\n' "$notes"
