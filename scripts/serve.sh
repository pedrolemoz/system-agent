#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
dist="$repo_root/dist"
public="$repo_root/public"

if [ -z "$repo_root" ] || [ "$dist" != "$repo_root/dist" ] || [ "$public" != "$repo_root/public" ]; then
  echo 'Refusing to replace an unexpected path.' >&2
  exit 1
fi

rm -rf "$dist"
rm -rf "$public"
mkdir -p "$public"

bash "$repo_root/scripts/build.sh"

cp \
  "$dist/systemagent.exe" \
  "$dist/systemagent-linux" \
  "$dist/systemagent-mac" \
  "$repo_root/scripts/install.ps1" \
  "$repo_root/scripts/install.sh" \
  "$public/"

echo "Copied hosted artifacts to $public."
