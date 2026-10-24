#!/bin/bash
set -euo pipefail

source_dir="$(cd "$(dirname "$0")" && pwd)"
stage_dir="$(cd "$source_dir/.." && pwd)"
build_dir="$stage_dir/02_build"
objects="$build_dir/01_objects"
app="$build_dir/工作时钟.app"
arch="$(uname -m)"

mkdir -p "$objects" "$app/Contents/MacOS" "$app/Contents/Resources"
/usr/bin/xcrun clang -arch "$arch" -fobjc-arc -fblocks -O2 -Wall -Wextra \
  -Wno-deprecated-declarations -mmacosx-version-min=14.0 \
  -framework Cocoa -framework CoreGraphics \
  "$source_dir/WorkTime.m" -o "$app/Contents/MacOS/WorkTime"

/usr/bin/xcrun clang -arch "$arch" -fobjc-arc -O2 -framework Cocoa \
  "$source_dir/IconMaker.m" -o "$objects/icon-maker"
"$objects/icon-maker" "$objects/AppIcon.iconset"
/bin/cp "$objects/AppIcon.iconset/icon_512x512@2x.png" "$app/Contents/Resources/AppIcon.png"
/bin/cp "$source_dir/Info.plist" "$app/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$app"
/usr/bin/codesign --verify --deep --strict "$app"
/usr/bin/plutil -lint "$app/Contents/Info.plist"
echo "$app"
