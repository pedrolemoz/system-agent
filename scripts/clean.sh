#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
dist="$repo_root/dist"

if [ "$dist" != "$repo_root/dist" ] || [ -z "$repo_root" ]; then
  echo 'Refusing to clean an unexpected path.' >&2
  exit 1
fi

rm -rf "$dist"
echo 'Removed dist build artifacts.'
