#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
rm -rf dist
mkdir -p dist

version="${VERSION:-dev}"
build_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ldflags="-s -w -X main.version=${version} -X main.buildTime=${build_time}"

build() {
  local os="$1" arch="$2" output="$3"
  echo "Building ${os}/${arch} -> dist/${output}"
  CGO_ENABLED=0 GOOS="$os" GOARCH="$arch" go build -trimpath -ldflags "$ldflags" -o "dist/$output" ./cmd/systemagent
}

# These three names correspond to the public /windows, /linux, and /mac URLs.
build windows amd64 systemagent.exe
build linux amd64 systemagent-linux
build darwin arm64 systemagent-mac

# Architecture-specific artifacts make it possible to expand the download routing later.
build windows arm64 systemagent-windows-arm64.exe
build linux arm64 systemagent-linux-arm64
build darwin amd64 systemagent-mac-amd64

(cd dist && sha256sum * > SHA256SUMS)
echo "Build complete. Artifacts are in dist/."
