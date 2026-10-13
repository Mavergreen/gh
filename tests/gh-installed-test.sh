#!/bin/sh
# platform: macOS-only -- reads an installed gh pkg and 10.9's own /bin/bash and /bin/zsh
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers/assert.sh"
[ $# -eq 1 ] || { echo "skip: usage: gh-installed-test.sh PREFIX (an installed gh, e.g. /usr/local/mavergreen/gh)" >&2; exit 77; }
P="$1"
[ -x "$P/bin/gh" ] || { echo "skip: no gh installed at $P" >&2; exit 77; }

t_tmp H
unset MANPATH || true
export HOME="$H"
a_eq /usr/local/mavergreen/share/man/man1/gh.1 "$(man -w gh)" "man finds gh's page through the link farm"
/bin/bash -n "$P/share/bash-completion/completions/gh" && _b=ok || _b=bad
a_eq ok "$_b" "10.9's /bin/bash parses gh's bash completion"
/bin/zsh -n "$P/share/zsh/site-functions/_gh" && _z=ok || _z=bad
a_eq ok "$_z" "10.9's /bin/zsh parses gh's zsh completion"
[ -s "$P/share/fish/vendor_completions.d/gh.fish" ] && _f=ok || _f=bad
a_eq ok "$_f" "the fish completion is there"
a_done
