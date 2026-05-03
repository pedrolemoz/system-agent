#!/bin/sh
# Build system-agent binaries for all supported platforms
set -e

BINARY_NAME="system-agent"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/dist"

mkdir -p "$OUT_DIR"

echo "Output: $OUT_DIR"
echo ""
echo "=== Building Go binaries ==="

build() {
  GOOS="$1" GOARCH="$2" GOARM="${3:-}" CGO_ENABLED=0 \
    go build -trimpath -ldflags="-s -w" -o "$OUT_DIR/$4" "$ROOT_DIR/cmd/agent"
  echo "  OK  $4"
}

(cd "$ROOT_DIR" && \
  build linux  amd64 ""  "${BINARY_NAME}-linux-amd64" && \
  build linux  arm64 ""  "${BINARY_NAME}-linux-arm64" && \
  build linux  arm   7   "${BINARY_NAME}-linux-armv7" && \
  build windows amd64 "" "${BINARY_NAME}.exe"
)

echo ""
echo "Artifacts in dist/:"
ls -lh "$OUT_DIR"
