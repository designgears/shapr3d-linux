#!/usr/bin/env bash
# Build a release AppImage of Shapr3D for Linux from committed, pushed sources, and test it.
#
#   ./release.sh VERSION            e.g. ./release.sh 2026.10.1
#
# The wine-uwp it builds is the submodule (wine-uwp/), pinned to a commit that must be on GitHub, so the release
# can always be rebuilt. Everything goes to out/ (gitignored): out/build is the build state (the SDK build's cache
# included; the first build compiles Wine), out/VERSION the release files:
#
#   shapr3d-linux-VERSION-x86_64.AppImage   with AppImageUpdate info for this repo's GitHub releases
#   shapr3d-linux-VERSION-x86_64.AppImage.zsync
#   SHA256SUMS
#   smoke.png, smoke.log                    appimage/smoke.sh's run (set SMOKE_PACKAGE and SMOKE_ISO or
#                                           SMOKE_WINDOWS; SMOKE=0 skips it, and the release is then untested)
#
# Needs: clang-cl, lld-link and the xwin SDK in ~/xwin (the shims), org.flatpak.Builder with the freedesktop 25.08
# SDK and its mingw-w64 and rust-stable extensions (appimage/build.sh), Xvfb, xdotool and ImageMagick (the smoke test).
set -euo pipefail
version=${1:?usage: ./release.sh VERSION}
here=$(cd "$(dirname "$0")" && pwd)
cd "$here"
repo=designgears/shapr3d-linux
name=shapr3d-linux-$version-x86_64.AppImage
rel=$here/out/$version
fail() { echo "release: $*" >&2; exit 1; }

echo "STAGE Checking the sources"
git submodule update --init wine-uwp
[ -z "$(git status --porcelain)" ] || fail "uncommitted changes in shapr3d-linux (git status)"
[ -z "$(git -C wine-uwp status --porcelain)" ] || fail "uncommitted changes in the wine-uwp submodule"
git -C wine-uwp fetch -q origin
[ -n "$(git -C wine-uwp branch -r --contains HEAD)" ] || fail "wine-uwp $(git -C wine-uwp rev-parse --short HEAD) is not on GitHub; push it first"
(cd wine-uwp && ./check-clean.sh --all) || fail "wine-uwp: check-clean.sh"
WINE_UWP=$here/wine-uwp wine-uwp/check-clean.sh --all || fail "shapr3d-linux: check-clean.sh"
[ ! -e "$rel" ] || fail "$rel exists; a version is built once"

export WINE_UWP=$here/wine-uwp UWP_BIN=$here/out/build RELEASE_VERSION=$version
mkdir -p "$UWP_BIN" "$rel"

echo "STAGE Building the shims"
"$WINE_UWP/build.sh"

echo "STAGE Building the AppImage"
APPIMAGE_NAME=$name UPDATE_INFO="gh-releases-zsync|${repo%/*}|${repo#*/}|latest|shapr3d-linux-*x86_64.AppImage.zsync" \
  appimage/build.sh "$rel"
rm -rf "$rel/AppDir"
[ -f "$rel/$name.zsync" ] || fail "appimagetool wrote no $name.zsync"
(cd "$rel" && sha256sum "$name" "$name.zsync" > SHA256SUMS)

if [ "${SMOKE:-1}" = 0 ]; then
  echo "release: SMOKE=0, the AppImage was not tested" >&2
else
  echo "STAGE Smoke test"
  appimage/smoke.sh "$rel/$name" "$rel"
fi
echo "release: $rel"
ls -la "$rel"
