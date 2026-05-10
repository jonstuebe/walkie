#!/usr/bin/env bash
# Renders all Walkie app icons (primary + alternates) by compiling the
# in-app KoalaView together with the icon generator and running the result
# against the macOS toolchain's SwiftUI ImageRenderer.

set -euo pipefail

cd "$(dirname "$0")/.."

OUT=$(mktemp -d)
BIN="$OUT/walkie-icongen"

xcrun -sdk macosx swiftc \
  -O \
  Walkie/Models/PetColor.swift \
  Walkie/Views/KoalaView.swift \
  scripts/generate_icon.swift \
  -o "$BIN"

"$BIN" Walkie/Assets.xcassets

rm -rf "$OUT"
