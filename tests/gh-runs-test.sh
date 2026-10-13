#!/bin/sh
# platform: macOS-only -- executes the darwin/amd64 gh this repo builds
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/.." && pwd)"
. "$HERE/helpers/assert.sh"
[ $# -eq 1 ] || { echo "skip: usage: gh-runs-test.sh GH (the gh under test; an installed one may be stale)" >&2; exit 77; }
GH="$1"

[ "$(uname -m)" = x86_64 ] || { echo "skip: needs an x86_64 host; this is never run translated" >&2; exit 77; }
[ -x "$GH" ] || { echo "skip: no gh at $GH" >&2; exit 77; }

t_tmp H
unset GH_CONFIG_DIR GH_TOKEN GITHUB_TOKEN GH_HOST XDG_CONFIG_HOME XDG_STATE_HOME XDG_DATA_HOME XDG_CACHE_HOME || true
export HOME="$H"

out="$("$GH" version)" || a_eq 0 $? "gh version exits 0"
first="$(printf '%s\n' "$out" | sed -n 1p)"
want="gh version $(cat "$MAVERICKS_ROOT/UPSTREAM_VERSION") ("
case "$first" in
  "$want"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]")") a_eq "$first" "$first" "gh version reports the upstream version and its date" ;;
  *) a_eq "${want}YYYY-MM-DD)" "$first" "gh version reports the upstream version and its date" ;;
esac
help="$("$GH" help)" || a_eq 0 $? "gh help exits 0"
[ -n "$help" ] || a_eq "some help text" "" "gh help prints something"
a_contains "$help" "gh <command>" "gh help prints its usage"
lic="$("$GH" licenses)" || a_eq 0 $? "gh licenses exits 0"
a_contains "$lic" "GitHub CLI third-party dependencies" "gh licenses prints the embedded notices"
case "$lic" in *"only available in official release builds"*) a_eq "embedded notices" "the placeholder message" "gh licenses is not the unembedded fallback" ;; esac
a_done
