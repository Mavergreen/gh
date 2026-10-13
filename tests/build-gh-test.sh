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
mkdir -p "$T/fixture/script"
cat > "$T/fixture/script/licenses" <<STUB
#!/bin/bash
printf 'LICENSES %s GOOS=%s GOARCH=%s GOBIN=%s GO=%s GOSUMDB=%s\n' "\$*" "\${GOOS-unset}" "\${GOARCH-unset}" "\${GOBIN-}" "\$(command -v go)" "\${GOSUMDB-}" >> "$T/log"
d="internal/licenses/embed/\$1-\$2"
mkdir -p "\$d"
printf 'GitHub CLI third-party dependencies\n' > "\$d/report.txt"
if [ -z "\${STUB_LICENSES_NO_THIRD_PARTY-}" ]; then
  mkdir -p "\$d/third-party/example.com/m"
  printf 'example license\n' > "\$d/third-party/example.com/m/LICENSE"
  chmod -R a-w "\$d/third-party"
fi
STUB
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
    cat > "\$o" <<'GH'
#!/bin/sh
[ "\$1" = completion ] && [ "\$2" = -s ] || exit 3
[ -n "\${STUB_EMPTY_COMPLETION-}" ] || printf '# %s completion for gh\n' "\$3"
GH
    chmod +x "\$o" ;;
  run)
    printf 'GENDOCS GH_VERSION=%s SOURCE_DATE_EPOCH=%s GOOS=%s GOARCH=%s\n' "\${GH_VERSION-}" "\${SOURCE_DATE_EPOCH-}" "\${GOOS-unset}" "\${GOARCH-unset}" >> "$T/log"
    [ -z "\${STUB_FAIL_GENDOCS-}" ] || exit 1
    d=""; prev=""
    for a in "\$@"; do [ "\$prev" = "--doc-path" ] && d="\$a"; prev="\$a"; done
    [ "\$2" = ./cmd/gen-docs ] && [ "\$3" = --man-page ] && [ -n "\$d" ] || exit 4
    mkdir -p "\$d"; printf '.TH "GH" "1"\n' > "\$d/gh.1"; printf '.TH "GH-PR" "1"\n' > "\$d/gh-pr.1" ;;
esac
STUB
chmod +x "$T/bin/go"
printf '#!/bin/sh\n[ "$1" = -m ] && echo "${STUB_UNAME:-arm64}" || /usr/bin/uname "$@"\n' > "$T/bin/uname"
chmod +x "$T/bin/uname"
PATH="$T/bin:$PATH"

export MAVERICKS_BUILD_ROOT="$T/buildroot"
mkdir -p "$T/out/share/man/man1"; printf 'stale\n' > "$T/out/share/man/man1/gh-stale.1"
GOSUMDB=off GONOSUMDB='*' GONOSUMCHECK=1 GOPRIVATE='*' GOINSECURE='*' GOFLAGS=-tags=updateable GOENV="$T/hostile.env" \
  sh "$SCRIPT" "$T/bin/go" "$T/out" 2.102.0 >/dev/null
log="$(cat "$T/log")"

a_eq 1 "$(grep -c '^ARGS mod download -json github.com/cli/cli/v2@v2.102.0$' "$T/log")" "one checksum-verified module download"
build="$(grep "^ARGS build .*-o $T/out/gh " "$T/log")"
a_eq 2 "$(grep -c '^ENV GOTOOLCHAIN=local CGO_ENABLED=0 GOOS=darwin GOARCH=amd64$' "$T/log")" "both calls run with the pinned env"
a_eq 4 "$(grep -c '^VERIFY GOENV=off GOFLAGS= GOSUMDB=sum.golang.org GONOSUMDB= GONOSUMCHECK= GOPRIVATE= GOINSECURE=$' "$T/log")" "checksum verification and flags never come from the caller's environment or go env file"
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

a_eq 1 "$(grep -c '^GENDOCS GH_VERSION=2.102.0 SOURCE_DATE_EPOCH=1790736002 GOOS=unset GOARCH=unset$' "$T/log")" "gen-docs: version and module date, host arch"
a_file_exists "gh.1 generated" "$T/out/share/man/man1/gh.1"
a_file_exists "subcommand pages generated" "$T/out/share/man/man1/gh-pr.1"
a_no_file "a man page from an earlier build does not linger" "$T/out/share/man/man1/gh-stale.1"
a_eq "# bash completion for gh" "$(cat "$T/out/share/bash-completion/completions/gh")" "bash completion as gh prints it"
a_eq "# zsh completion for gh" "$(cat "$T/out/share/zsh/site-functions/_gh")" "zsh completion as gh prints it"
a_eq "# fish completion for gh" "$(cat "$T/out/share/fish/vendor_completions.d/gh.fish")" "fish completion as gh prints it"
a_no_file "no Debian vendor-completions copy" "$T/out/share/zsh/vendor-completions"
a_eq 2 "$(grep -c '^ARGS build ' "$T/log")" "off x86_64, a host-arch gh is built to print the completions"
hostenv="$(grep -A1 "^ARGS build .*-o $T/buildroot/gh-work/host/gh " "$T/log" | sed -n 2p)"
a_eq "ENV GOTOOLCHAIN=local CGO_ENABLED=0 GOOS= GOARCH=" "$hostenv" "the host gh is built for this host"

lic="$(grep '^LICENSES ' "$T/log" || true)"
a_eq 1 "$(grep -c '^LICENSES darwin amd64 GOOS=unset GOARCH=unset ' "$T/log")" "script/licenses reports on darwin/amd64 from a host-arch environment"
a_contains "$lic" "GOBIN=$T/buildroot/gh-work/hostbin " "go-licenses installs into the build root"
a_contains "$lic" "GO=$T/bin/go " "script/licenses runs the pinned go"
a_contains "$lic" "GOSUMDB=sum.golang.org" "go-licenses is checksum-verified"
lic_at="$(grep -n '^LICENSES ' "$T/log" | head -1 | cut -d: -f1)"
build_at="$(grep -n "^ARGS build .*-o $T/out/gh " "$T/log" | head -1 | cut -d: -f1)"
[ -n "$lic_at" ] && [ -n "$build_at" ] && [ "$lic_at" -lt "$build_at" ] && _o=before || _o=after
a_eq before "$_o" "the notices exist before the build that embeds them"
rc=0; sh "$SCRIPT" "$T/bin/go" "$T/out" 2.102.0 >/dev/null 2>&1 || rc=$?
a_eq 0 "$rc" "a rebuild over read-only license files from the module cache succeeds"

rc=0; sh "$SCRIPT" >/dev/null 2>&1 || rc=$?
a_eq 2 "$rc" "no args is a usage error"

rm -rf "$T/out"
a_fails "a failed module download fails the build" env STUB_FAIL_DOWNLOAD=1 sh "$SCRIPT" "$T/bin/go" "$T/out" 2.102.0
a_no_file "no gh after a failed download" "$T/out/gh"
a_fails "a failed go build fails the script" env STUB_FAIL_BUILD=1 sh "$SCRIPT" "$T/bin/go" "$T/out" 2.102.0
a_fails "a failed gen-docs fails the build" env STUB_FAIL_GENDOCS=1 sh "$SCRIPT" "$T/bin/go" "$T/out" 2.102.0
a_fails "an empty completion fails the build" env STUB_EMPTY_COMPLETION=1 sh "$SCRIPT" "$T/bin/go" "$T/out" 2.102.0
: > "$T/log"; rm -rf "$T/out"
STUB_UNAME=x86_64 sh "$SCRIPT" "$T/bin/go" "$T/out" 2.102.0 >/dev/null
a_eq 1 "$(grep -c '^ARGS build ' "$T/log")" "on x86_64 the target gh prints the completions itself"
a_eq "# zsh completion for gh" "$(cat "$T/out/share/zsh/site-functions/_gh")" "and they are still there"
a_fails "no third-party license texts fails the build" env STUB_LICENSES_NO_THIRD_PARTY=1 sh "$SCRIPT" "$T/bin/go" "$T/out" 2.102.0
a_done
