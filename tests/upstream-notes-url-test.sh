#!/bin/sh
# platform: host-agnostic
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/.." && pwd)"
. "$HERE/helpers/assert.sh"

a_eq "https://github.com/cli/cli/releases/tag/v2.102.0" "$(sh "$MAVERICKS_ROOT/build/upstream-release-notes-url.sh" 2.102.0)" "the notes URL is upstream's tag page"
a_fails "no version is a usage error" sh "$MAVERICKS_ROOT/build/upstream-release-notes-url.sh"
a_done
