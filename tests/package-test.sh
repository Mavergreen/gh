#!/bin/sh
# platform: macOS-only -- pkgutil expands the product archive and lsbom lists the component's payload
#   usage: package-test.sh PKG GH-BIN
#          The pkg must be named gh-<version>.pkg and its gh component must carry exactly bin/gh, gh's
#          man pages (at least 100 share/man/man1/gh*.1), its bash, zsh and fish completions, gh's
#          LICENSE and the README under share/doc/gh, the mavergreen.plist manifest, and the updater app
#          (Sparkle framework aside) with its LaunchAgent; every file in it is world-readable and every
#          directory world-searchable; the packaged gh must be byte-identical to the one that was tested.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers/assert.sh"
PKG="${1:-}"; GHBIN="${2:-}"
[ -n "$PKG" ] && [ -n "$GHBIN" ] || { echo "package-test: usage: package-test.sh PKG GH-BIN" >&2; exit 77; }

case "$(basename "$PKG")" in gh-[0-9]*.pkg) _n=ok ;; *) _n=bad ;; esac
a_eq ok "$_n" "the pkg is named gh-<version>.pkg"
a_file_exists "the pkg exists" "$PKG"
a_file_exists "the tested gh exists" "$GHBIN"

t_tmp T
pkgutil --expand "$PKG" "$T/x"
C="$T/x/gh-component.pkg"
a_file_exists "the product archive carries the gh component" "$C/Bom"
lsbom -s -f "$C/Bom" | sed 's|^\./||' > "$T/bom"
a_eq 1 "$(grep -c 'gh-updater\.app/Contents/Frameworks/Sparkle\.framework/Versions/A/Sparkle$' "$T/bom")" "the Sparkle binary is in the payload"
lsbom "$C/Bom" | sed 's|^\./||' > "$T/modes"
a_eq "" "$(awk -F'\t' '{ m = $2; o = substr(m, length(m)) + 0 }
  m ~ /^10/ && int(o / 4) % 2 == 0 { print $1 " " m }
  m ~ /^4/ && o % 2 == 0 { print $1 " " m }' "$T/modes")" "every payload file is world-readable and every directory world-searchable"
a_eq "100755" "$(awk -F'\t' '$1 == "usr/local/mavergreen/gh/bin/gh" { print $2 }' "$T/modes")" "gh is executable"
MAN='^usr/local/mavergreen/gh/share/man/man1/gh[^/]*\.1$'
grep -v '/Sparkle\.framework/' "$T/bom" | grep -v "$MAN" | LC_ALL=C sort > "$T/payload"
a_eq 1 "$(grep -c '^usr/local/mavergreen/gh/share/man/man1/gh\.1$' "$T/bom")" "the payload carries gh.1"
[ "$(grep -c "$MAN" "$T/bom")" -ge 100 ] && _m=many || _m="$(grep -c "$MAN" "$T/bom")"
a_eq many "$_m" "the payload carries upstream's man pages (at least 100 gh*.1)"

a_eq "Library/Application Support/Mavergreen/gh-updater.app/Contents/Info.plist
Library/Application Support/Mavergreen/gh-updater.app/Contents/MacOS/gh-updater
Library/LaunchAgents/dev.mavergreen.gh-updatecheck.plist
usr/local/mavergreen/gh/bin/gh
usr/local/mavergreen/gh/mavergreen.plist
usr/local/mavergreen/gh/share/bash-completion/completions/gh
usr/local/mavergreen/gh/share/doc/gh/LICENSE
usr/local/mavergreen/gh/share/doc/gh/README.md
usr/local/mavergreen/gh/share/fish/vendor_completions.d/gh.fish
usr/local/mavergreen/gh/share/zsh/site-functions/_gh" "$(cat "$T/payload")" "the payload is gh, its man pages, completions and docs, the manifest, the updater and its LaunchAgent"

mkdir "$T/out"
( cd "$T/out" && gzip -dc < "$C/Payload" | cpio -id 2>/dev/null )
a_file_exists "gh extracts" "$T/out/usr/local/mavergreen/gh/bin/gh"
cmp "$T/out/usr/local/mavergreen/gh/bin/gh" "$GHBIN" && _s=same || _s=differs
a_eq same "$_s" "the packaged gh is byte-identical to the tested one"
a_done
