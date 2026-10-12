#!/bin/sh
# platform: host-agnostic
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers/assert.sh"

t_tmp T
rc=0; sh "$HERE/gh-runs-test.sh" 2>"$T/err" || rc=$?
a_eq 77 "$rc" "with no gh named, the smoke test skips"
a_contains "$(cat "$T/err")" "usage: gh-runs-test.sh GH" "and says it needs the gh to test, never reaching for an installed one"
a_done
