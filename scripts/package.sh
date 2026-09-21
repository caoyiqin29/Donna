#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-1.0.22}"
BUILD="$ROOT/build"
STAGING="$BUILD/release-$VERSION"
DIST="$ROOT/build/dist"

"$ROOT/scripts/build.sh"
mkdir -p "$STAGING" "$DIST"
cp -R "$BUILD/每日待办.app" "$STAGING/每日待办.app"
ln -s /Applications "$STAGING/Applications"

ditto -c -k --sequesterRsrc "$STAGING" "$DIST/每日待办-$VERSION-macOS-universal.zip"
hdiutil create \
  -volname "每日待办 $VERSION" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DIST/每日待办-$VERSION-macOS-universal.dmg"

shasum -a 256 "$DIST"/*
