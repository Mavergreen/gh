#!/bin/sh
# platform: host-agnostic -- the guard reads Mach-O anywhere, but its strict Objective-C analyzer (drydock-objc) measures on macOS only today and says it cannot measure elsewhere
#   usage: compat-guard.sh GH
#          gh's 10.9 compat guard: the floor, the SDK, no post-10.9 import, _clock_gettime defined in
#          the binary, and every Objective-C send measured by the strict analyzer.
set -eu
[ $# -eq 1 ] || { echo "usage: compat-guard.sh GH" >&2; exit 2; }
REPO="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO/build/msc.sh"
MAVERICKS_REQUIRE_DEFINED_SYMBOLS=_clock_gettime MAVERGREEN_OBJC_STRICT=1 \
  exec sh "$SHIPYARD_SCRIPTS/assert_binary_compatible.sh" "$1"
