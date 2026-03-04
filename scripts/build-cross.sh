#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP="self-study-tool"

mkdir -p "$DIST_DIR"

build() {
  local goos="$1"
  local goarch="$2"
  local ext="$3"
  local out="$DIST_DIR/${APP}-${goos}-${goarch}${ext}"
  echo "Building $out"
  CGO_ENABLED=0 GOOS="$goos" GOARCH="$goarch" go build -o "$out" "$ROOT_DIR/cmd/server"
}

build windows amd64 .exe
build linux amd64 ""
build android arm64 ""

echo "Done. Artifacts in $DIST_DIR"
