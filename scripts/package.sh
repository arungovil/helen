#!/bin/bash
# Builds a universal Helen.app (ad-hoc signed) and zips it into dist/.
# Usage: scripts/package.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0}"
ARCHS=(--arch arm64 --arch x86_64)

swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

APP="dist/Helen.app"
rm -rf dist
mkdir -p "$APP/Contents/"{MacOS,Frameworks,Resources}

cp "$BIN/helen" "$APP/Contents/MacOS/"
cp "$BIN/libMediaRemoteAdapter.dylib" "$APP/Contents/Frameworks/"
# SwiftPM's Bundle.module looks in Contents/Resources when linked into an app.
cp -R "$BIN"/*.bundle "$APP/Contents/Resources/"
# @loader_path, not @executable_path: the adapter has perl dlopen() our binary, so
# @executable_path would resolve against perl and miss the dylib.
install_name_tool -add_rpath "@loader_path/../Frameworks" "$APP/Contents/MacOS/helen"

# Sources/helen/Info.plist is the single source of truth; only the version is stamped here.
cp Sources/helen/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy \
  -c "Set :CFBundleShortVersionString $VERSION" \
  -c "Set :CFBundleVersion $VERSION" \
  "$APP/Contents/Info.plist"

# Apple Silicon refuses unsigned binaries; ad-hoc signing is free but not notarized.
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

ditto -c -k --keepParent "$APP" "dist/Helen-$VERSION.zip"
echo "Built dist/Helen-$VERSION.zip"
