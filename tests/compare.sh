#!/bin/bash
# Compares stock Ubuntu php7.4 with the built packages in a throwaway container.
#   tests/compare.sh <folder-with-built-debs> [results-dir]     (default results: ./results)
set -euo pipefail
cd "$(dirname "$0")/.."
DEBS=$(cd "${1:?usage: tests/compare.sh <debs-dir> [results-dir]}" && pwd)
RES="${2:-results}"; mkdir -p "$RES"; RES=$(cd "$RES" && pwd)
docker run --rm --init --platform linux/amd64 \
  -v "$PWD":/src:ro -v "$DEBS":/debs:ro -v "$RES":/results \
  ubuntu:20.04 bash /src/tests/compare-in-container.sh
