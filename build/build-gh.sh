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

rm -rf "$SRC"; mkdir -p "$SRC"
cp -R "$dir/." "$SRC"
chmod -R u+w "$SRC"
find "$SRC" -name '._*' -delete
# spec: INGREDIENTS.md "Decisions" -- upstream's -s -w, but no -linkmode (the toolchain external-links darwin/amd64)
LD="-s -w -X github.com/cli/cli/v2/internal/build.Version=$VERSION -X github.com/cli/cli/v2/internal/build.Date=$date"
cd "$SRC"
"$GO" build -trimpath -ldflags "$LD" -o "$OUT/gh" ./cmd/gh
cp "$SRC/LICENSE" "$OUT/LICENSE"
