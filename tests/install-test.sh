#!/bin/bash
# Runs install.sh -> verify.sh -> rollback.sh against stock php7.4 in a throwaway container.
#   tests/install-test.sh <folder-with-built-debs-and-SHA256SUMS>
set -euo pipefail
cd "$(dirname "$0")/.."
DEBS=$(cd "${1:?usage: tests/install-test.sh <debs-dir>}" && pwd)
docker run --rm --init --platform linux/amd64 -v "$PWD":/src:ro -v "$DEBS":/debs:ro \
  ubuntu:20.04 bash /src/tests/install-test-in-container.sh
