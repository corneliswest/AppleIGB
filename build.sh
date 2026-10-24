#!/bin/zsh
# Build AppleIGB.kext with Xcode 26.x (the Command Line Tools cannot build kexts).
# Usage: ./build.sh <version> [Release|Debug]      e.g. ./build.sh 5.12.0
set -euo pipefail
V="${1:?usage: build.sh <version> [Release|Debug]}"
CFG="${2:-Release}"
ROOT="${0:A:h}"
XCODE="${XCODE_APP:-/Users/cw/Downloads/Xcode.app}"
XCB="$XCODE/Contents/Developer/usr/bin/xcodebuild"
[ -x "$XCB" ] || { echo "xcodebuild not found at $XCB (set XCODE_APP=/path/to/Xcode.app)"; exit 1; }
export DEVELOPER_DIR="$XCODE/Contents/Developer"
mkdir -p "$ROOT/dist" "$ROOT/logs"
LOG="$ROOT/logs/build-$V-$CFG.txt"
echo "Building AppleIGB $V ($CFG) with $("$XCB" -version | head -1) ..."
if ! "$XCB" -project "$ROOT/AppleIGB.xcodeproj" -configuration "$CFG" -arch x86_64 ONLY_ACTIVE_ARCH=NO \
      CURRENT_PROJECT_VERSION="$V" MARKETING_VERSION="$V" SYMROOT="$ROOT/build" CODE_SIGN_IDENTITY=- build > "$LOG" 2>&1; then
  echo "BUILD FAILED, see $LOG"; grep -E 'error:' "$LOG" | head -40; exit 1
fi
SRC="$ROOT/build/$CFG/AppleIGB.kext"
SUFFIX=""; [ "$CFG" = "Release" ] || SUFFIX="-$CFG"
OUT="$ROOT/dist/AppleIGB-$V$SUFFIX.kext"
rm -rf "$OUT"; cp -R "$SRC" "$OUT"
echo "Warnings: $(grep -c 'warning:' "$LOG" || true)   Log: $LOG"
echo "Kext:     $OUT"
echo "Version:  $(plutil -extract CFBundleVersion raw -o - "$OUT/Contents/Info.plist")"
echo "Binary:   $(file -b "$OUT/Contents/MacOS/AppleIGB")"
echo "SHA-256:  $(shasum -a 256 "$OUT/Contents/MacOS/AppleIGB" | cut -d' ' -f1)"
