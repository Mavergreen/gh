#!/bin/sh
# platform: host-agnostic
#   usage: build-updater.sh OUT-DIR
#          Builds gh-updater.app through shipyard's build_updater.sh with clang22 at components/clang22's pin:
#          x86_64 at 10.9 and, off 10.9, arm64 at 11.0. The version is VERSION's when the release wrote one,
#          else UPSTREAM_VERSION's. Prints OUT-DIR/gh-updater.app.
# spec: SKILL.md "The compiler: clang22 on every host" -- and Apple Silicon installs this pkg too, where an
#       x86_64-only updater prompts for Rosetta
set -eu
[ $# -eq 1 ] || { echo "usage: build-updater.sh OUT-DIR" >&2; exit 2; }
REPO="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO/build/msc.sh"
V="$REPO/VERSION"; [ -f "$V" ] || V="$REPO/UPSTREAM_VERSION"
ver="$(sed 1q "$V")"
arm=""; [ "$(sh "$SHIPYARD_SCRIPTS/mavericks_mode.sh")" = native ] || arm="--arch arm64"
# shellcheck disable=SC2086
exec sh "$SHIPYARD_SCRIPTS/build_updater.sh" --product gh --display-name "Mavericks GitHub CLI" \
  --confirm-title "GitHub CLI for Mavericks updated" \
  --confirm-body "gh was updated. New shells and agents get the new version." \
  --pubkey "$REPO/updater/ed25519_key.pub" --version "$ver" --clang22-pin "$REPO/components/clang22" \
  --arch x86_64 $arm --generic-icon --out-dir "$1"
