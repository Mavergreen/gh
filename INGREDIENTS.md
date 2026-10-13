# Build ingredients

Everything baked into what GitHub CLI for Mavericks ships, and how a change to it reaches a release.

| Ingredient | Pinned in | Renovate | On a bump |
|---|---|---|---|
| gh source (own upstream: the `github.com/cli/cli/v2` module, verified by the Go checksum database) | `UPSTREAM_VERSION` | ✅ `github-releases` on `cli/cli` | a push to main cuts `-mavericks.1` |
| golang-127 cross toolchain (builds `gh`; its runtime and the legacy-support shim are linked in) | `components/golang/version` | ✅ `github-releases` on `Mavergreen/golang-127`, `-mavericks.N` versioning | a bump repackages |
| MacOSX10.9 SDK, CMake modules, compat guard, packaging and signing scripts | `Mavergreen/shipyard@v1` | ✅ github-actions manager tracks the tag | `@v1` moves without the pin changing, so nothing repackages by itself |
| Sparkle, in the updater | shipyard's `fetch_sparkle_framework.sh`, pinned by hash there | ❌ untrackable here: shipyard owns that pin | follows shipyard |
| go-licenses (generates the notices `gh licenses` prints) | upstream's `script/licenses` | ❌ untrackable here: upstream owns that pin | follows `UPSTREAM_VERSION` |

## Declared state

- upstream: UPSTREAM_VERSION
- golang: components/golang/version

## Decisions

The package carries an x86_64 `gh` only, not a universal one. Go 1.27's darwin/arm64 linker stamps a
macOS 13.0 floor, so it cannot produce an arm64 slice at the family's floor of 11.0, and a 13.0
slice would make Apple Silicon Macs on 11 or 12 pick it and fail instead of falling back to x86_64.
Exit: when golang-port ships darwin/arm64 output with an 11.0 floor, reconsider universal.

`gh` is linked with upstream's flags (`-s -w`, `-trimpath`), except `-linkmode=external`: the golang
toolchain already external-links every darwin/amd64 binary through its 10.9 CC wrapper, and with
`CGO_ENABLED=0` (upstream's darwin setting) Go rejects the flag outright. Stripping still leaves
`_clock_gettime` defined where the compat guard can see it, which is how it proves the legacy-support
shim was linked (`MAVERICKS_REQUIRE_DEFINED_SYMBOLS`).

`gh version` prints the bare upstream version (`2.102.0`), not this package's `2.102.0-mavericks.N`,
as tailscale does. The package version is in the `.pkg` name, the release tag and the updater.

The compat guard allows one "selector", `labelColor` (`MAVERICKS_ALLOW_SELECTORS`). `gh` contains no
Objective-C at all: no `__objc` sections and no Objective-C imports. The guard finds the word through
`strings`, because the terminal UI library tview has a Go struct field named `labelColor`, and Go
keeps field names in the binary's type data. Exit: when the guard reads selectors only from
`__objc_methname`, drop the allowance.

`gh` is built without upstream's `updateable` tag, so it never tells users to fetch GitHub's build,
which cannot run on 10.9. The Sparkle updater is the update channel.

## Man pages, completions and license notices

Each is made by upstream's own tool, as upstream's release does:

- `script/licenses darwin amd64` installs go-licenses at the commit it pins and writes the report and
  license texts that `gh licenses` prints into `internal/licenses/embed/darwin-amd64`, before the build
  embeds them.
- `go run ./cmd/gen-docs --man-page` writes `gh.1` and a page per subcommand. `GH_VERSION` fills each
  page's source line, and `SOURCE_DATE_EPOCH`, taken from the module's release time, dates the pages by
  the release instead of the build day.
- `gh completion -s bash|zsh|fish` prints the completions, shipped as printed.

All three tools are built for the build host, with `GOOS` and `GOARCH` set to its own
`go env GOHOSTOS`/`GOHOSTARCH`: unsetting them is not enough, because the cross toolchain's own
`go.env` defaults them to darwin/amd64. On an arm64 Mac a host-arch `gh` built from the same source
prints the completions, so no build step runs under Rosetta. On an amd64 host the `gh` being shipped
prints them itself.

The man pages install under `share/man/man1`, which the link farm exports, so `man gh` works after
install. The completions install under `share/bash-completion/completions`,
`share/zsh/site-functions` and `share/fish/vendor_completions.d` in gh's own tree, and nothing hooks
them into a shell. The bash script also needs the bash-completion package, which 10.9 doesn't ship.

## Releasing

A merged `UPSTREAM_VERSION` bump releases itself: the push to `main` cuts `-mavericks.1`.

A packaging-only release of the same source (a new `.N`):

    gh workflow run release.yml -R Mavergreen/gh --ref main -f local_release=true
