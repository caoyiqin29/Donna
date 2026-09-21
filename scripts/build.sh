#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/每日待办.app"
SOURCE="$ROOT/Sources/FloatingTodo.swift"
ARCH="${ARCH:-$(uname -m)}"
MODULE_CACHE="$BUILD/module-cache/$ARCH"

rm -rf "$APP" "$BUILD/FloatingTodo"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$MODULE_CACHE"

swiftc \
  -O \
  -target "$ARCH-apple-macos12.0" \
  -module-cache-path "$MODULE_CACHE" \
  -framework AppKit \
  -framework WebKit \
  "$SOURCE" \
  -o "$BUILD/FloatingTodo"

mv "$BUILD/FloatingTodo" "$APP/Contents/MacOS/FloatingTodo"

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
chmod +x "$APP/Contents/MacOS/FloatingTodo"
codesign --force --deep --sign - "$APP"

echo "Built: $APP"
file "$APP/Contents/MacOS/FloatingTodo"
