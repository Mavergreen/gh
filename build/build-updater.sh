#!/bin/sh
# platform: host-agnostic
#   usage: build-updater.sh OUT-DIR
#          Builds gh-updater.app with clang22 (build/fetch-clang22.sh), one configure per arch: x86_64 at
#          10.9 and, off 10.9, arm64 at 11.0, merged with llvm-lipo. Prints OUT-DIR/gh-updater.app.
# spec: SKILL.md "The compiler: clang22 on every host" -- and Apple Silicon installs this pkg too, where an
#       x86_64-only updater prompts for Rosetta
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT=${1:?usage: build-updater.sh OUT-DIR}
. "$REPO/build/msc.sh"
if [ "$(uname -s)" = Linux ]; then SC="$(command -v cmake)"
else SC="$(command -v shipyard-cmake || echo /usr/local/mavergreen/bin/shipyard-cmake)"; fi
TC="$(dirname "$SHIPYARD_SCRIPTS")/MavericksToolchain.cmake"
CL="$(sh "$REPO/build/fetch-clang22.sh")"
LIPO="$CL/bin/llvm-lipo"; OTOOL="$CL/bin/llvm-otool"; NM="$CL/bin/llvm-nm"; STRINGS="$CL/bin/llvm-strings"
export LIPO OTOOL NM STRINGS
W="${MAVERICKS_BUILD_ROOT:-${TMPDIR:-/tmp}/mm-build}/$(basename "$REPO")-updater"
slices="x86_64:10.9"; [ "$(sh "$SHIPYARD_SCRIPTS/mavericks_mode.sh")" = native ] || slices="x86_64:10.9 arm64:11.0"
for s in $slices; do
  a="${s%%:*}"; floor="${s#*:}"
  rm -rf "$W/$a"
  "$SC" -S "$REPO/updater" -B "$W/$a" -DCMAKE_TOOLCHAIN_FILE="$TC" -DCMAKE_OSX_ARCHITECTURES="$a" \
    -DCMAKE_OBJC_COMPILER="$CL/bin/clang" -DCMAKE_OBJC_COMPILER_TARGET="$a-apple-macos$floor" \
    -DCMAKE_OBJC_FLAGS=--no-default-config -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld --ld-path=$CL/bin/ld64.lld" >&2
  "$SC" --build "$W/$a" >&2
done
app="$OUT/gh-updater.app"; rm -rf "$app"; mkdir -p "$OUT"
case "$slices" in
  *arm64*) sh "$SHIPYARD_SCRIPTS/lipo-merge-tree.sh" --a "$W/x86_64/gh-updater.app" --b "$W/arm64/gh-updater.app" \
             --out "$app" --require-archs "x86_64 arm64" >&2 ;;
  *) cp -R "$W/x86_64/gh-updater.app" "$app" ;;
esac
echo "$app"
