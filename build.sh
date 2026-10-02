#!/usr/bin/env bash
#
# StrongBox release builder
# -------------------------
# Assembles a flashable Magisk/KernelSU module zip from:
#   1. this repository (all StrongBox files), and
#   2. a "donor" release zip that provides the prebuilt PIF artifacts which are
#      not tracked in this repo (classes.dex, zygisk/*.so, legacy/*, osm0sis.sh,
#      migrate.sh, credits.md, toolkit defaults, META-INF/...).
#
# A donor is either an upstream IntegrityBox release zip (recommended: the
# release matching this fork's base, e.g. v43) or a PlayIntegrityFork release
# zip. Repo files always win; donor files are kept only where the repo does not
# define its own version.
#
# After overlaying, the script regenerates:
#   - toolkit/modulehash  (sha256 of the shipped module.prop)
#   - hash                (install-time integrity manifest checked by verify.sh)
# and verifies the manifest before packaging.
#
# Usage:
#   ./build.sh <donor-release.zip> [output-name]
#
# Examples:
#   ./build.sh ~/Downloads/v43-Integrity-Box-26-09-2026.zip
#     -> dist/StrongBox-1.0.0.zip
#   ./build.sh /tmp/pif-release.zip StrongBox-nightly.zip
#
# Publishing:
#   gh release create v1.0.0 dist/StrongBox-1.0.0.zip \
#       --title "StrongBox v1.0.0" --notes-file changelog.md

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DONOR="${1:-}"
OUT_NAME="${2:-}"

if [ -z "$DONOR" ] || [ ! -f "$DONOR" ]; then
    echo "usage: $0 <donor-release.zip> [output-name]" >&2
    exit 1
fi

command -v unzip >/dev/null 2>&1 || { echo "error: 'unzip' not found" >&2; exit 1; }
command -v zip   >/dev/null 2>&1 || { echo "error: 'zip' not found" >&2; exit 1; }
command -v tar   >/dev/null 2>&1 || { echo "error: 'tar' not found" >&2; exit 1; }
if command -v sha256sum >/dev/null 2>&1; then
    SHA="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    SHA="shasum -a 256"
else
    echo "error: need sha256sum or shasum" >&2
    exit 1
fi

VERSION="$(sed -n 's/^version=//p' "$ROOT/module.prop")"
CODE="$(sed -n 's/^versionCode=//p' "$ROOT/module.prop")"
[ -n "$VERSION" ] && [ -n "$CODE" ] || { echo "error: cannot read version from module.prop" >&2; exit 1; }
[ -n "$OUT_NAME" ] || OUT_NAME="StrongBox-$VERSION.zip"

# release.json must track module.prop, or OTA updates break.
REL_VER="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$ROOT/release.json")"
REL_CODE="$(sed -n 's/.*"versionCode": *\([0-9]*\).*/\1/p' "$ROOT/release.json")"
REL_ASSET="$(sed -n 's|.*/download/[^/]*/\([^/"]*\)".*|\1|p' "$ROOT/release.json")"
[ "$REL_VER" = "$VERSION" ] || { echo "error: release.json version '$REL_VER' != module.prop '$VERSION' (update release.json)" >&2; exit 1; }
[ "$REL_CODE" = "$CODE" ] || { echo "error: release.json versionCode '$REL_CODE' != module.prop '$CODE' (update release.json)" >&2; exit 1; }
if [ "$REL_ASSET" != "$OUT_NAME" ]; then
    echo "note: release.json expects asset '$REL_ASSET', but this build produces '$OUT_NAME'." >&2
    echo "      Publish it under a tag whose release contains the expected asset name." >&2
fi

DIST="$ROOT/dist"
BUILD="$DIST/build"
OUT="$DIST/$OUT_NAME"

rm -rf "$BUILD"
mkdir -p "$BUILD" "$DIST"

echo "==> StrongBox $VERSION ($CODE)"
echo "==> extracting donor: $DONOR"
unzip -q "$DONOR" -d "$BUILD"
if [ ! -f "$BUILD/classes.dex" ]; then
    echo "warning: donor has no classes.dex — is it an IntegrityBox or PlayIntegrityFork release zip?" >&2
fi

# The integrity manifest is regenerated below; the donor copy must not survive.
rm -f "$BUILD/hash"

echo "==> overlaying repository files"
( cd "$ROOT" && tar cf - \
    --exclude='./.git' \
    --exclude='./.github' \
    --exclude='./.gitattributes' \
    --exclude='./.gitignore' \
    --exclude='./.gitmodules' \
    --exclude='./LICENSE' \
    --exclude='./README.md' \
    --exclude='./changelog.md' \
    --exclude='./release.json' \
    --exclude='./build.sh' \
    --exclude='./dist' \
    --exclude='./assets' \
    --exclude='./DEVELOPING.md' \
    --exclude='./tests' \
    --exclude='./.editorconfig' \
    --exclude='./.shellcheckrc' \
    --exclude='./PlayIntegrityFork' \
    . ) | ( cd "$BUILD" && tar xf - )

# Donor-only leftovers that are intentionally not part of StrongBox
# (unreferenced legacy upstream pages/assets; keep in sync if upstream adds more)
rm -rf "$BUILD/webroot/KeyboxLoader" \
       "$BUILD/webroot/KeyboxSource" \
       "$BUILD/webroot/RepairMode" \
       "$BUILD/webroot/RootImplementation"
rm -f  "$BUILD/webroot/meowna.ttf" \
       "$BUILD/webroot/marked.min.js" \
       "$BUILD/webroot/service-worker.js"

# Donor-only helper scripts that nothing in this fork invokes. Upstream calls
# them from donor files our fork replaces (action.sh / post-fs-data.sh / the
# Control page), so they are dead weight here. Keep teesim.sh — it IS used.
rm -f "$BUILD/webroot/common_scripts/gms.sh" \
      "$BUILD/webroot/common_scripts/hehe.sh" \
      "$BUILD/webroot/common_scripts/hma.sh" \
      "$BUILD/webroot/common_scripts/kernel.sh" \
      "$BUILD/webroot/common_scripts/multiroot.sh" \
      "$BUILD/webroot/common_scripts/scan_keybox.sh" \
      "$BUILD/webroot/common_scripts/updateprop.sh" \
      "$BUILD/webroot/common_scripts/webui.sh" \
      "$BUILD/webroot/common_scripts/zygisk.sh"
rm -f "$BUILD/toolkit/stock.prop"   # only read by the removed updateprop.sh

echo "==> regenerating toolkit/modulehash"
printf '%s' "$($SHA "$BUILD/module.prop" | cut -d' ' -f1)" > "$BUILD/toolkit/modulehash"

echo "==> regenerating integrity manifest (hash)"
HASH_FILE="$BUILD/hash"
( cd "$BUILD" && find . -type f ! -path './META-INF/*' ! -name 'hash' -print \
    | sed 's|^\./||' | LC_ALL=C sort \
    | while IFS= read -r f; do
        printf '%s|%s\n' "$f" "$($SHA "$f" | cut -d' ' -f1)"
    done > "$HASH_FILE" )

echo "==> verifying manifest"
( cd "$BUILD" && fail=0
  while IFS='|' read -r f h; do
      a="$($SHA "$f" | cut -d' ' -f1)"
      if [ "$a" != "$h" ]; then
          echo "MISMATCH: $f" >&2
          fail=1
      fi
  done < "$HASH_FILE"
  [ "$fail" -eq 0 ] || exit 1
  echo "    $(wc -l < "$HASH_FILE") entries verified" )

echo "==> packaging"
rm -f "$OUT"
( cd "$BUILD" && zip -qr9 "$OUT" . )

rm -rf "$BUILD"

echo
echo "built: $OUT"
echo "  module:  StrongBox $VERSION (versionCode $CODE)"
echo "  release: tag v$VERSION, asset $(basename "$OUT")"
echo
echo "publish:"
echo "  gh release create v$VERSION \"dist/$(basename "$OUT")\" --title \"StrongBox v$VERSION\" --notes-file changelog.md"
