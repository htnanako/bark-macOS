#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SOURCE_PNG="${1:-$ROOT_DIR/Resources/AppIcon.png}"
OUTPUT_ICNS="${2:-$ROOT_DIR/Resources/BarkMac.icns}"
ICONSET_DIR="${OUTPUT_ICNS:r}.iconset"

if [[ ! -f "$SOURCE_PNG" ]]; then
  echo "Missing source PNG: $SOURCE_PNG" >&2
  exit 1
fi

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

render_icon() {
  local size="$1"
  local filename="$2"
  sips -z "$size" "$size" "$SOURCE_PNG" --out "$ICONSET_DIR/$filename" >/dev/null
}

render_icon 16 icon_16x16.png
render_icon 32 icon_16x16@2x.png
render_icon 32 icon_32x32.png
render_icon 64 icon_32x32@2x.png
render_icon 128 icon_128x128.png
render_icon 256 icon_128x128@2x.png
render_icon 256 icon_256x256.png
render_icon 512 icon_256x256@2x.png
render_icon 512 icon_512x512.png
render_icon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

echo "Built icon:"
echo "  $OUTPUT_ICNS"
