#!/bin/sh
# platform: host-agnostic
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers/assert.sh"

t_tmp T
rc=0; sh "$HERE/gh-installed-test.sh" 2>"$T/err" || rc=$?
a_eq 77 "$rc" "with no prefix named, the installed test skips"
a_contains "$(cat "$T/err")" "usage: gh-installed-test.sh PREFIX" "and says it needs the installed prefix, never guessing one"
a_done
