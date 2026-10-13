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
# platform: date -j is BSD and date -d is GNU, so awk turns the RFC 3339 UTC time into Unix seconds
epoch="$(sed -n 's/.*"Time":"\([0-9T:-]*\)Z".*/\1/p' "$info" | awk -F'[-T:]' '{
  y = $1; m = $2; if (m <= 2) y--; era = int(y / 400); yoe = y - era * 400
  doy = int((153 * ((m + 9) % 12) + 2) / 5) + $3 - 1; doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
  print (era * 146097 + doe - 719468) * 86400 + $4 * 3600 + $5 * 60 + $6 }')"
[ -n "$epoch" ] || { echo "build-gh.sh: no UTC Time in $info" >&2; exit 1; }

# platform: go-licenses copies read-only files out of the module cache, and rm -rf can't remove them
chmod -R u+w "$SRC" 2>/dev/null || true
rm -rf "$SRC"; mkdir -p "$SRC"
cp -R "$dir/." "$SRC"
chmod -R u+w "$SRC"
find "$SRC" -name '._*' -delete
# spec: INGREDIENTS.md "Decisions" -- upstream's -s -w, but no -linkmode (the toolchain external-links darwin/amd64)
LD="-s -w -X github.com/cli/cli/v2/internal/build.Version=$VERSION -X github.com/cli/cli/v2/internal/build.Date=$date"
cd "$SRC"
# spec: INGREDIENTS.md "Man pages, completions and license notices" -- the cross toolchain's own go.env
#       defaults GOOS/GOARCH to darwin/amd64, so host tools name the host explicitly
hostos="$("$GO" env GOHOSTOS)"; hostarch="$("$GO" env GOHOSTARCH)"
[ -n "$hostos" ] && [ -n "$hostarch" ] || { echo "build-gh.sh: $GO env GOHOSTOS/GOHOSTARCH printed nothing" >&2; exit 1; }
# platform: bash 3.2's set -e ignores a failing ( ) subshell
run_host() { ( GOOS=$hostos GOARCH=$hostarch; export GOOS GOARCH; "$@" ) || exit 1; }

# spec: INGREDIENTS.md "Man pages, completions and license notices" -- upstream's script/licenses, unchanged,
#       builds go-licenses for this host and reports on darwin/amd64; gh embeds what it writes
run_host env PATH="$(dirname "$GO"):$WORK/hostbin:$PATH" GOBIN="$WORK/hostbin" bash script/licenses darwin amd64
emb="$SRC/internal/licenses/embed/darwin-amd64"
[ -s "$emb/report.txt" ] || { echo "build-gh.sh: script/licenses produced no $emb/report.txt" >&2; exit 1; }
[ -n "$(find "$emb/third-party" -type f 2>/dev/null | head -1)" ] || { echo "build-gh.sh: script/licenses produced no third-party license texts in $emb" >&2; exit 1; }
"$GO" build -trimpath -ldflags "$LD" -o "$OUT/gh" ./cmd/gh
cp "$SRC/LICENSE" "$OUT/LICENSE"

rm -rf "$OUT/share"
mkdir -p "$OUT/share/man/man1" "$OUT/share/bash-completion/completions" \
  "$OUT/share/zsh/site-functions" "$OUT/share/fish/vendor_completions.d"
# spec: INGREDIENTS.md "Man pages, completions and license notices" -- upstream's gen-docs; GH_VERSION
#       fills each page's Source and SOURCE_DATE_EPOCH dates it by the release, not the build
run_host env GH_VERSION="$VERSION" SOURCE_DATE_EPOCH="$epoch" "$GO" run ./cmd/gen-docs --man-page --doc-path "$OUT/share/man/man1"
[ -s "$OUT/share/man/man1/gh.1" ] || { echo "build-gh.sh: gen-docs wrote no gh.1" >&2; exit 1; }

# spec: INGREDIENTS.md "Man pages, completions and license notices" -- no build step runs translated, so off
#       amd64 a host-arch gh built from the same source prints the completions
case "$hostos/$hostarch" in
  darwin/amd64) gen="$OUT/gh" ;;
  *)
    mkdir -p "$WORK/host"
    run_host "$GO" build -trimpath -o "$WORK/host/gh" ./cmd/gh
    gen="$WORK/host/gh" ;;
esac
completion() {
  "$gen" completion -s "$1" > "$OUT/share/$2" || { echo "build-gh.sh: gh completion -s $1 failed" >&2; exit 1; }
  [ -s "$OUT/share/$2" ] || { echo "build-gh.sh: gh completion -s $1 wrote nothing" >&2; exit 1; }
}
completion bash bash-completion/completions/gh
completion zsh zsh/site-functions/_gh
completion fish fish/vendor_completions.d/gh.fish
