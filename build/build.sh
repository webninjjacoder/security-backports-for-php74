#!/bin/bash
# Builds the patched php7.4 packages in Docker. Run from anywhere:
#   build/build.sh [output-dir]      (default: ./out)
# Takes ~30-60 min on a native x86-64 host; roughly double under emulation (Apple Silicon).
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-out}"
mkdir -p "$OUT"
docker build --platform linux/amd64 -t security-backports-php74-builder build
docker run --rm --platform linux/amd64 \
  -v "$PWD":/src:ro -v "$(cd "$OUT" && pwd)":/out \
  security-backports-php74-builder bash /src/build/build-in-container.sh
