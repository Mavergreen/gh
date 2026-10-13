#!/bin/sh
# platform: host-agnostic
set -eu
[ $# -eq 3 ] || { echo "usage: build-gh.sh GO OUT VERSION" >&2; exit 2; }
GO=$1; OUT=$2; VERSION=$3
case "$OUT" in /*) ;; *) OUT="$(pwd)/$OUT" ;; esac

WORK="${MAVERICKS_BUILD_ROOT:-${TMPDIR:-/tmp}/mm-build}/gh-work"
SRC="$WORK/src"
export GOMODCACHE="$WORK/gomodcache" GOCACHE="$WORK/gocache" COPYFILE_DISABLE=1
# spec: INGREDIENTS.md "Declared state" -- the golang pin is the only Go; never download another
export GOTOOLCHAIN=local CGO_ENABLED=0 GOOS=darwin GOARCH=amd64
# spec: INGREDIENTS.md (gh source row) -- the checksum database verifies the module, whatever the caller's env says
export GOENV=off GOFLAGS= GOSUMDB=sum.golang.org
unset GONOSUMDB GONOSUMCHECK GOPRIVATE GOINSECURE
mkdir -p "$WORK" "$OUT"

json="$("$GO" mod download -json "github.com/cli/cli/v2@v$VERSION")"
[ -n "$json" ] || { echo "build-gh.sh: go mod download printed nothing" >&2; exit 1; }
dir="$(printf '%s\n' "$json" | sed -n 's/^[[:space:]]*"Dir": "\(.*\)",*$/\1/p')"
info="$(printf '%s\n' "$json" | sed -n 's/^[[:space:]]*"Info": "\(.*\)",*$/\1/p')"
[ -d "$dir" ] && [ -f "$info" ] || { echo "build-gh.sh: no module Dir/Info in: $json" >&2; exit 1; }
date="$(sed -n 's/.*"Time":"\([0-9-]*\)T.*/\1/p' "$info")"
[ -n "$date" ] || { echo "build-gh.sh: no Time in $info" >&2; exit 1; }

# platform: go-licenses copies read-only files out of the module cache, and rm -rf can't remove them
chmod -R u+w "$SRC" 2>/dev/null || true
rm -rf "$SRC"; mkdir -p "$SRC"
cp -R "$dir/." "$SRC"
chmod -R u+w "$SRC"
find "$SRC" -name '._*' -delete
# spec: INGREDIENTS.md "Decisions" -- upstream's -s -w, but no -linkmode (the toolchain external-links darwin/amd64)
LD="-s -w -X github.com/cli/cli/v2/internal/build.Version=$VERSION -X github.com/cli/cli/v2/internal/build.Date=$date"
cd "$SRC"
# platform: 10.9's env has no -u, and bash 3.2's set -e ignores a failing ( ) subshell
run_host() { ( unset GOOS GOARCH; "$@" ) || exit 1; }

# spec: INGREDIENTS.md "Man pages, completions and license notices" -- upstream's script/licenses, unchanged,
#       builds go-licenses for this host and reports on darwin/amd64; gh embeds what it writes
run_host env PATH="$(dirname "$GO"):$WORK/hostbin:$PATH" GOBIN="$WORK/hostbin" bash script/licenses darwin amd64
emb="$SRC/internal/licenses/embed/darwin-amd64"
[ -s "$emb/report.txt" ] || { echo "build-gh.sh: script/licenses produced no $emb/report.txt" >&2; exit 1; }
[ -n "$(find "$emb/third-party" -type f 2>/dev/null | head -1)" ] || { echo "build-gh.sh: script/licenses produced no third-party license texts in $emb" >&2; exit 1; }
"$GO" build -trimpath -ldflags "$LD" -o "$OUT/gh" ./cmd/gh
cp "$SRC/LICENSE" "$OUT/LICENSE"
