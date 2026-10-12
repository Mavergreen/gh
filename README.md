# GitHub CLI for Mavericks

**This README has not been read or edited by a human yet.** Until it has, this project cannot cut
its first release.

[GitHub CLI](https://github.com/cli/cli) (`gh`) for Mac OS X 10.9 Mavericks.

GitHub's own macOS build needs a newer macOS. This one is built from the same upstream source with a
Go toolchain that still targets 10.9.

## How to use

Install the `.pkg` from this repo's latest release. `gh` lands at `/usr/local/mavergreen/bin/gh`,
which new login shells find on their `PATH`.

```sh
gh auth login
gh auth setup-git
```

The second line makes `gh` git's credential helper for github.com, so pushes over HTTPS need no
SSH agent.

The bundled updater keeps `gh` current. `gh` itself never suggests fetching GitHub's build.

Unofficial community build; not affiliated with GitHub.
