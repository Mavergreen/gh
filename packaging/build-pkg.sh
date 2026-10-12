#!/bin/sh
# platform: macOS-only -- drives shipyard's stage_product.sh, build_component_pkg.sh and set_install_floor.sh
#   usage: build-pkg.sh UPDATER-APP GH-BIN LICENSE VERSION OUT-DIR
#          Stages gh (byte for byte as built and tested), gh's LICENSE, the README and the updater under
#          /usr/local/mavergreen/gh, and wraps them in a 10.9.5-floored product archive,
#          OUT-DIR/gh-VERSION.pkg, whose path it prints.
set -eu
U="usage: build-pkg.sh UPDATER-APP GH-BIN LICENSE VERSION OUT-DIR"
APP=${1:?$U}
GHBIN=${2:?$U}
LICENSE_SRC=${3:?$U}
V=${4:?$U}
OUTDIR=${5:?$U}
REPO=$(cd "$(dirname "$0")/.." && pwd)
MAVERICKS_ROOT=$REPO; export MAVERICKS_ROOT
. "$REPO/build/lib.sh"
[ -f "$GHBIN" ] || { echo "build-pkg: no $GHBIN" >&2; exit 1; }
[ -f "$LICENSE_SRC" ] || { echo "build-pkg: no $LICENSE_SRC" >&2; exit 1; }
[ -d "$APP" ] || { echo "build-pkg: no updater $APP; configure with -DGH_BUILD_UPDATER=ON" >&2; exit 1; }
work=$(mktemp -d "${TMPDIR:-/tmp}/gh-pkg.XXXXXX")
trap 'rm -rf "$work"' EXIT
ROOT=$work/root
T=$ROOT/usr/local/mavergreen/gh
install -d "$T/bin" "$T/share/doc/gh"
cp -p "$GHBIN" "$T/bin/gh"
cp "$LICENSE_SRC" "$T/share/doc/gh/LICENSE"
cp "$REPO/README.md" "$T/share/doc/gh/"
find "$ROOT" -name '._*' -delete
sh "$SHIPYARD/stage_product.sh" --stage "$ROOT" --product gh --name "GitHub CLI for Mavericks" --version "$V" \
  --scripts-out "$work/scripts" --updater-app "$APP" >&2
sh "$SHIPYARD/build_component_pkg.sh" --root "$ROOT" --identifier dev.mavergreen.gh \
  --version "$V" --install-location / --scripts "$work/scripts" --out "$work/gh-component.pkg" >&2
mkdir -p "$OUTDIR"
OUT=$OUTDIR/gh-$V.pkg
sh "$SHIPYARD/set_install_floor.sh" --identifier dev.mavergreen.gh --title "GitHub CLI for Mavericks" \
  --component "$work/gh-component.pkg" --out "$OUT" --require-scripts --host-arch x86_64 >&2
echo "$OUT"
