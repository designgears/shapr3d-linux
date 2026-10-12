#!/usr/bin/env bash
# Build Shapr3D for Linux in the freedesktop 25.08 SDK and export it as a single-file Flatpak bundle. The same build
# is what appimage/build.sh packs as the AppImage, so run this first.
#
#   flatpak/build.sh [OUTDIR]       OUTDIR gets FLATPAK_NAME (default shapr3d-linux-x86_64.flatpak)
#
# Needs org.flatpak.Builder and org.freedesktop.Sdk//25.08 with its mingw-w64 and rust-stable extensions from Flathub
# (flatpak install --user flathub ...), and wine-uwp's shims built (its build.sh). The first build compiles Wine and
# takes a while; later ones reuse flatpak-builder's cache in $UWP_BIN/sdk-build.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../env.sh"
id=io.github.designgears.Shapr3DLinux
sdk=${SDK_BUILD:-$UWP_BIN/sdk-build}
out=$(realpath -m "${1:-$UWP_BIN/flatpak}")
mkdir -p "$sdk" "$out"

echo "STAGE Building in the freedesktop SDK"
# the manifest's local sources, under .build/: wine-uwp's runtime (scripts and shims), our Wine source from the
# wine-uwp checkout; the installer is ../installer
"$WINE_UWP/packaging/build-dist.sh" --no-wine "$here/.build/dist" | grep -v '^STAGE Done'
rm -rf "$here/.build/wine"; cp -a --reflink=auto "$WINE_UWP/wine" "$here/.build/wine"
# what this build is: share/wine-uwp/VERSION has wine-uwp's commit; this adds the release and this repo's commit
{ echo "${RELEASE_VERSION:-dev}"; git -C "$SHAPR3D_LINUX" rev-parse --short HEAD; } > "$here/.build/dist/share/wine-uwp/SHAPR3D_LINUX_VERSION"
flatpak run --filesystem="$SHAPR3D_LINUX" --filesystem="$sdk" org.flatpak.Builder \
  --user --force-clean --ccache --state-dir="$sdk/state" --repo="$sdk/repo" "$sdk/build" "$here/$id.yml"

echo "STAGE Exporting the Flatpak"
name=${FLATPAK_NAME:-shapr3d-linux-x86_64.flatpak}
flatpak build-bundle --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo "$sdk/repo" "$out/$name" "$id"
echo "flatpak: $out/$name ($(du -h "$out/$name" | cut -f1))"
