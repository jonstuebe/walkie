#!/usr/bin/env bash
# Renders the Walkie splash image by compiling the in-app KoalaView together
# with the splash generator and running the result against the macOS
# toolchain's SwiftUI ImageRenderer. Output lands in Assets.xcassets as
# Splash.imageset.

set -euo pipefail

cd "$(dirname "$0")/.."

OUT=$(mktemp -d)
BIN="$OUT/walkie-splashgen"

xcrun -sdk macosx swiftc \
  -O \
  Walkie/Models/PetColor.swift \
  Walkie/Views/KoalaView.swift \
  scripts/generate_splash.swift \
  -o "$BIN"

"$BIN" Walkie/Assets.xcassets

rm -rf "$OUT"
