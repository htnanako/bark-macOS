#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
VERSION=$(tr -d '[:space:]' < "$ROOT_DIR/version.txt")
OUTPUT_DIR="$ROOT_DIR/.local/dev"

"$ROOT_DIR/scripts/package-app.sh" \
  --configuration debug \
  --version "$VERSION" \
  --build-number 0 \
  --bundle-id "me.fin.bark.macos.local" \
  --output-dir "$OUTPUT_DIR"

open "$OUTPUT_DIR/BarkMac.app"
