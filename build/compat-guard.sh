#!/bin/sh
# platform: host-agnostic -- clang22's Mach-O readers and drydock-objc's strict analyzer measure on any host
#   usage: compat-guard.sh GH
#          gh's 10.9 compat guard: the floor, the SDK, no post-10.9 import, _clock_gettime defined in
#          the binary, and every Objective-C send measured by the strict analyzer.
set -eu
[ $# -eq 1 ] || { echo "usage: compat-guard.sh GH" >&2; exit 2; }
REPO="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO/build/msc.sh"
CL="$(sh "$REPO/build/fetch-clang22.sh")"
export LIPO="${LIPO:-$CL/bin/llvm-lipo}" OTOOL="${OTOOL:-$CL/bin/llvm-otool}" \
  NM="${NM:-$CL/bin/llvm-nm}" STRINGS="${STRINGS:-$CL/bin/llvm-strings}"
MAVERICKS_REQUIRE_DEFINED_SYMBOLS=_clock_gettime MAVERGREEN_OBJC_STRICT=1 \
  exec sh "$SHIPYARD_SCRIPTS/assert_binary_compatible.sh" "$1"
