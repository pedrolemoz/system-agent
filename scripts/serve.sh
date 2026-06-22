#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
public="$repo_root/public"

if [ -z "$repo_root" ] || [ "$public" != "$repo_root/public" ]; then
  echo 'Refusing to replace an unexpected path.' >&2
  exit 1
fi

rm -rf "$public"
mkdir -p "$public"

cp \
  "$repo_root/dist/systemagent.exe" \
  "$repo_root/dist/systemagent-linux" \
  "$repo_root/dist/systemagent-mac" \
  "$repo_root/scripts/install.ps1" \
  "$repo_root/scripts/install.sh" \
  "$repo_root/scripts/uninstall.ps1" \
  "$repo_root/scripts/uninstall.sh" \
  "$public/"

cd "$public"
exec python -m http.server 2767
