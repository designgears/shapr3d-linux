#!/usr/bin/env bash
# Build the Shapr3D for Linux Flatpak and a single-file bundle of it.
#
#   flatpak/build.sh [--install]
#
# Needs org.flatpak.Builder, org.freedesktop.Sdk//25.08 with its mingw-w64 and rust-stable extensions from Flathub
# (flatpak install --user flathub ...). Output: $UWP_BIN/flatpak/repo (an OSTree repo) and
# $UWP_BIN/flatpak/wine-uwp.flatpak (flatpak install --user wine-uwp.flatpak). --install also installs it for this
# user. The first build compiles Wine and takes a while; later ones reuse flatpak-builder's cache.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../env.sh"
out=${FLATPAK_OUT:-$UWP_BIN/flatpak}
id=io.github.wine_uwp.WineUWP
mkdir -p "$out"

# the manifest's local sources, gathered under .build/: wine-uwp's runtime (scripts and shims), our Wine source
# from the wine-uwp checkout, and the installer from this repo
"$WINE_UWP/packaging/build-dist.sh" --no-wine "$here/.build/dist" | grep -v '^STAGE Done'
rm -rf "$here/.build/wine"; cp -a --reflink=auto "$WINE_UWP/wine" "$here/.build/wine"
# what this build is: share/wine-uwp/VERSION has wine-uwp's commit; this adds the release and this repo's commit
{ echo "${RELEASE_VERSION:-dev}"; git -C "$SHAPR3D_LINUX" rev-parse --short HEAD; } > "$here/.build/dist/share/wine-uwp/SHAPR3D_LINUX_VERSION"

builder=(flatpak run --filesystem="$SHAPR3D_LINUX" --filesystem="$out" org.flatpak.Builder)
"${builder[@]}" --user --force-clean --ccache --state-dir="$out/state" --repo="$out/repo" \
  ${1:+$([ "$1" = --install ] && echo --install)} "$out/build" "$here/$id.yml"
flatpak build-bundle "$out/repo" "$out/wine-uwp.flatpak" "$id"
echo "bundle: $out/wine-uwp.flatpak ($(du -h "$out/wine-uwp.flatpak" | cut -f1))"
