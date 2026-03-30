#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PRODUCT_NAME="BarkMac"
APP_NAME="${PRODUCT_NAME}.app"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.png"
ICON_FILE="$ROOT_DIR/Resources/${PRODUCT_NAME}.icns"
VERSION_FILE="$ROOT_DIR/version.txt"
PLIST_TEMPLATE="$ROOT_DIR/Resources/Info.plist.template"
DIST_DIR="$ROOT_DIR/dist"
OUTPUT_DIR=""
CONFIGURATION="release"
VERSION=""
BUILD_NUMBER="${GITHUB_RUN_NUMBER:-1}"
BUNDLE_ID="me.fin.bark.macos"
SIGN_IDENTITY="${APPLE_SIGN_IDENTITY:--}"
SKIP_CODESIGN="${SKIP_CODESIGN:-0}"
IS_CI="${CI:-${GITHUB_ACTIONS:-}}"

usage() {
  echo "usage: ./scripts/package-app.sh [--configuration debug|release] [--version 1.2.3] [--build-number 42] [--bundle-id id] [--output-dir path]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      CONFIGURATION="${2:-}"
      shift 2
      ;;
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --build-number)
      BUILD_NUMBER="${2:-}"
      shift 2
      ;;
    --bundle-id)
      BUNDLE_ID="${2:-}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --sign-identity)
      SIGN_IDENTITY="${2:-}"
      shift 2
      ;;
    --skip-codesign)
      SKIP_CODESIGN="1"
      shift 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$CONFIGURATION" != "debug" && "$CONFIGURATION" != "release" ]]; then
  usage
  exit 1
fi

if [[ -z "$VERSION" ]]; then
  if [[ ! -f "$VERSION_FILE" ]]; then
    echo "Missing version file: $VERSION_FILE" >&2
    exit 1
  fi
  VERSION=$(tr -d '[:space:]' < "$VERSION_FILE")
fi

VERSION="${VERSION#v}"
OUTPUT_DIR="${OUTPUT_DIR:-$DIST_DIR/$CONFIGURATION}"
APP_DIR="$OUTPUT_DIR/$APP_NAME"

if [[ ! -f "$PLIST_TEMPLATE" ]]; then
  echo "Missing Info.plist template: $PLIST_TEMPLATE" >&2
  exit 1
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Build number must be numeric for CFBundleVersion: $BUILD_NUMBER" >&2
  exit 1
fi

echo "Building $PRODUCT_NAME ($CONFIGURATION) version $VERSION ($BUILD_NUMBER)..."
echo "Step 1/6: Build Swift package"
if [[ -n "$IS_CI" ]]; then
  swift build -c "$CONFIGURATION"
else
  swift build -c "$CONFIGURATION" >/dev/null
fi

echo "Step 2/6: Resolve binary output path"
BIN_DIR=$(swift build -c "$CONFIGURATION" --show-bin-path)
EXECUTABLE="$BIN_DIR/$PRODUCT_NAME"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Missing executable at $EXECUTABLE" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

echo "Step 3/6: Assemble app bundle"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"

sound_files=("$ROOT_DIR"/Sources/BarkMac/Resources/*.caf(N))
if (( ${#sound_files[@]} > 0 )); then
  for sound_file in "${sound_files[@]}"; do
    destination="$APP_DIR/Contents/Resources/$(basename "$sound_file")"
    if ! afconvert "$sound_file" "$destination" -f caff -d ima4 >/dev/null 2>&1; then
      cp "$sound_file" "$destination"
    fi
  done
fi

for bundle in "$BIN_DIR"/*.bundle; do
  [[ -e "$bundle" ]] || continue
  cp -R "$bundle" "$APP_DIR/Contents/Resources/"
done

if [[ -f "$ICON_SOURCE" ]]; then
  echo "Step 4/6: Build app icon"
  if [[ -n "$IS_CI" ]]; then
    "$ROOT_DIR/scripts/build-icon.sh" "$ICON_SOURCE" "$ICON_FILE"
  else
    "$ROOT_DIR/scripts/build-icon.sh" "$ICON_SOURCE" "$ICON_FILE" >/dev/null
  fi
fi

if [[ -f "$ICON_FILE" ]]; then
  cp "$ICON_FILE" "$APP_DIR/Contents/Resources/$PRODUCT_NAME.icns"
fi

echo "Step 5/6: Generate Info.plist"
sed \
  -e "s|__PRODUCT_NAME__|$PRODUCT_NAME|g" \
  -e "s|__BUNDLE_ID__|$BUNDLE_ID|g" \
  -e "s|__APP_VERSION__|$VERSION|g" \
  -e "s|__BUILD_NUMBER__|$BUILD_NUMBER|g" \
  "$PLIST_TEMPLATE" > "$APP_DIR/Contents/Info.plist"

touch "$APP_DIR/Contents/PkgInfo"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

if [[ "$SKIP_CODESIGN" != "1" ]]; then
  echo "Step 6/6: Codesign app bundle"
  codesign --force --deep --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP_DIR"
fi

echo "Packaged app:"
echo "  $APP_DIR"
