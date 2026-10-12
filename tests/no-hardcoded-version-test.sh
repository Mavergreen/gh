#!/bin/sh
# platform: host-agnostic
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/.." && pwd)"
. "$HERE/helpers/assert.sh"

UPSTREAM="$(cat "$MAVERICKS_ROOT/UPSTREAM_VERSION")"
RE="$(printf '%s' "$UPSTREAM" | sed 's/\./\\./g')"
cd "$MAVERICKS_ROOT"
files="$(git ls-files build packaging .github/workflows CMakeLists.txt)" || { echo "not ok - git ls-files failed (not a git checkout?)" >&2; exit 1; }
[ -n "$files" ] || { echo "not ok - no tracked build machinery to scan" >&2; exit 1; }

a_eq 1 "$(printf 'x %s y\n' "$UPSTREAM" | grep -cE "$RE")" "the pattern matches a known versioned line"
hits=""
for f in $files; do
  [ -f "$f" ] || continue
  hits="$hits$(grep -nE "$RE" "$f" | sed "s|^|$f:|" || true)"
done
a_eq "" "$hits" "tracked build machinery names no gh version"
a_done
