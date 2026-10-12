#!/bin/sh
# platform: host-agnostic
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/.." && pwd)"
. "$HERE/helpers/assert.sh"
SCRIPT="$MAVERICKS_ROOT/build/build-gh.sh"

t_tmp T
trap 'chmod -R u+w "$T" 2>/dev/null; _a_cleanup' EXIT
mkdir -p "$T/fixture/cmd/gh" "$T/bin"
printf 'fixture license\n' > "$T/fixture/LICENSE"
printf 'module github.com/cli/cli/v2\n' > "$T/fixture/go.mod"
printf 'package main\n' > "$T/fixture/cmd/gh/main.go"
chmod -R a-w "$T/fixture"
printf '{"Version":"v2.102.0","Time":"2026-09-30T02:40:02Z"}\n' > "$T/fixture.info"
cat > "$T/bin/go" <<STUB
#!/bin/sh
{
  printf 'ARGS %s\n' "\$*"
  printf 'ENV GOTOOLCHAIN=%s CGO_ENABLED=%s GOOS=%s GOARCH=%s\n' "\${GOTOOLCHAIN-}" "\${CGO_ENABLED-}" "\${GOOS-}" "\${GOARCH-}"
  printf 'VERIFY GOENV=%s GOFLAGS=%s GOSUMDB=%s GONOSUMDB=%s GONOSUMCHECK=%s GOPRIVATE=%s GOINSECURE=%s\n' "\${GOENV-}" "\${GOFLAGS-}" "\${GOSUMDB-}" "\${GONOSUMDB-}" "\${GONOSUMCHECK-}" "\${GOPRIVATE-}" "\${GOINSECURE-}"
  printf 'PWD %s\n' "\$(pwd)"
} >> "$T/log"
case "\$1" in
  mod)
    [ -z "\${STUB_FAIL_DOWNLOAD-}" ] || exit 1
    printf '{\n\t"Path": "github.com/cli/cli/v2",\n\t"Dir": "%s",\n\t"Info": "%s"\n}\n' "$T/fixture" "$T/fixture.info" ;;
  build)
    o=""; prev=""
    for a in "\$@"; do [ "\$prev" = "-o" ] && o="\$a"; prev="\$a"; done
    [ -w . ] || exit 9
    [ -z "\${STUB_FAIL_BUILD-}" ] || exit 1
    printf 'binary\n' > "\$o" ;;
esac
STUB
chmod +x "$T/bin/go"

export MAVERICKS_BUILD_ROOT="$T/buildroot"
GOSUMDB=off GONOSUMDB='*' GONOSUMCHECK=1 GOPRIVATE='*' GOINSECURE='*' GOFLAGS=-tags=updateable GOENV="$T/hostile.env" \
  sh "$SCRIPT" "$T/bin/go" "$T/out" 2.102.0 >/dev/null
log="$(cat "$T/log")"

a_eq 1 "$(grep -c '^ARGS mod download -json github.com/cli/cli/v2@v2.102.0$' "$T/log")" "one checksum-verified module download"
build="$(grep '^ARGS build ' "$T/log")"
a_eq 2 "$(grep -c '^ENV GOTOOLCHAIN=local CGO_ENABLED=0 GOOS=darwin GOARCH=amd64$' "$T/log")" "both calls run with the pinned env"
a_eq 2 "$(grep -c '^VERIFY GOENV=off GOFLAGS= GOSUMDB=sum.golang.org GONOSUMDB= GONOSUMCHECK= GOPRIVATE= GOINSECURE=$' "$T/log")" "checksum verification and flags never come from the caller's environment or go env file"
a_contains "$build" "-ldflags" "build passes ldflags"
case "$build" in *-linkmode*) a_eq "" "$build" "no -linkmode: the toolchain external-links darwin/amd64 itself, and the flag is fatal with cgo off" ;; esac
a_contains "$build" "-X github.com/cli/cli/v2/internal/build.Version=2.102.0" "version stamp"
a_contains "$build" "-X github.com/cli/cli/v2/internal/build.Date=2026-09-30" "date stamp from the module's release time"
case "$build" in *updateable*) a_eq "" updateable "no updateable tag" ;; esac
a_contains "$build" "-ldflags -s -w " "stripped (-s -w), as upstream does"
a_eq "./cmd/gh" "${build##* }" "the package built is ./cmd/gh"
bpwd="$(grep '^PWD ' "$T/log" | tail -1)"; bpwd="${bpwd#PWD }"
a_eq "$(cd "$T/buildroot/gh-work/src" && pwd)" "$bpwd" "build runs in a writable copy under the build root"
a_file_exists "gh produced" "$T/out/gh"
a_eq "fixture license" "$(cat "$T/out/LICENSE")" "LICENSE is gh's, from the module"

rc=0; sh "$SCRIPT" >/dev/null 2>&1 || rc=$?
a_eq 2 "$rc" "no args is a usage error"

rm -rf "$T/out"
a_fails "a failed module download fails the build" env STUB_FAIL_DOWNLOAD=1 sh "$SCRIPT" "$T/bin/go" "$T/out" 2.102.0
a_no_file "no gh after a failed download" "$T/out/gh"
a_fails "a failed go build fails the script" env STUB_FAIL_BUILD=1 sh "$SCRIPT" "$T/bin/go" "$T/out" 2.102.0
a_done
