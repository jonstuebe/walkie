#!/usr/bin/env bash
# Renders the Walkie launch image (the "walkie" wordmark on a solid
# background) using the macOS toolchain's SwiftUI ImageRenderer. Output
# lands in Assets.xcassets as Splash.imageset.

set -euo pipefail

cd "$(dirname "$0")/.."

OUT=$(mktemp -d)
BIN="$OUT/walkie-splashgen"

xcrun -sdk macosx swiftc \
  -O \
  -parse-as-library \
  scripts/generate_splash.swift \
  -o "$BIN"

"$BIN" Walkie/Assets.xcassets

rm -rf "$OUT"
