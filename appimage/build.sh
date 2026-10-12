#!/usr/bin/env bash
# Build the Shapr3D for Linux AppImage.
#
#   appimage/build.sh [OUTDIR]
#
# Two steps. First Wine, 7-Zip, the installer and wine-uwp's runtime are built with flatpak-builder in the
# freedesktop 25.08 SDK (build-env.yml; nothing is exported or installed as a Flatpak), so that they link against
# that runtime's glibc. Then that tree becomes the AppDir, with the runtime's Python (the setup tools need only its
# standard library) and the libraries hosts do not reliably have (bundle_libs.py). Everything bundled needs at most
# GLIBC_2.38, so the AppImage runs on Ubuntu 24.04, Debian 13, Fedora 39 and newer. The host provides glibc, its GPU
# drivers (GL, Vulkan), X11/Wayland, fontconfig/freetype, audio and D-Bus.
#
# Needs org.flatpak.Builder and org.freedesktop.Sdk//25.08 with its mingw-w64 and rust-stable extensions from Flathub
# (flatpak install --user flathub ...), and the shims built (wine-uwp's build.sh). The first build compiles Wine and
# takes a while; later ones reuse flatpak-builder's cache in $UWP_BIN/sdk-build.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../env.sh"
sdk=${SDK_BUILD:-$UWP_BIN/sdk-build}

echo "STAGE Building in the freedesktop SDK"
# the manifest's local sources, under .build/: wine-uwp's runtime (scripts and shims), our Wine source from the
# wine-uwp checkout; the installer is ../installer
"$WINE_UWP/packaging/build-dist.sh" --no-wine "$here/.build/dist" | grep -v '^STAGE Done'
rm -rf "$here/.build/wine"; cp -a --reflink=auto "$WINE_UWP/wine" "$here/.build/wine"
# what this build is: share/wine-uwp/VERSION has wine-uwp's commit; this adds the release and this repo's commit
{ echo "${RELEASE_VERSION:-dev}"; git -C "$SHAPR3D_LINUX" rev-parse --short HEAD; } > "$here/.build/dist/share/wine-uwp/SHAPR3D_LINUX_VERSION"
mkdir -p "$sdk"
flatpak run --filesystem="$SHAPR3D_LINUX" --filesystem="$sdk" org.flatpak.Builder \
  --user --force-clean --ccache --state-dir="$sdk/state" "$sdk/build" "$here/build-env.yml"
files=$sdk/build/files
[ -x "$files/bin/wine" ] || { echo "the SDK build left no bin/wine in $files" >&2; exit 1; }

rt=$(flatpak info --user --show-location org.freedesktop.Platform//25.08 2>/dev/null ||
     flatpak info --show-location org.freedesktop.Platform//25.08)/files
out=$(realpath -m "${1:-$UWP_BIN/appimage}")
app=$out/AppDir
tool=$UWP_BIN/tools/appimagetool
[ -x "$tool" ] || { mkdir -p "$(dirname "$tool")"
  curl -sfL -o "$tool" https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x "$tool"; }

echo "STAGE Assembling the AppDir"
rm -rf "$app"; mkdir -p "$app/usr/lib/bundled"
cp -a "$files"/. "$app/usr"/
rm -rf "$app/usr"/{manifest.json,share/app-info,share/runtime,lib/debug}

echo "STAGE Adding Python"
py=$(basename "$(readlink -f "$rt/bin/python3")")
cp "$rt/bin/$py" "$app/usr/bin/python3"
ver=${py#python}
cp -a "$rt/lib/python$ver" "$app/usr/lib/"
rm -rf "$app/usr/lib/python$ver"/{test,idlelib,tkinter,turtledemo,ensurepip,lib2to3,site-packages,config-*}
find "$app/usr/lib/python$ver" -name __pycache__ -prune -exec rm -rf {} +

echo "STAGE Bundling libraries"
elves=("$app/usr/bin/python3" "$app/usr/bin/7zz" "$app/usr/bin/wine-uwp-installer" "$app/usr/bin/wine" "$app/usr/bin/wineserver")
# Wine's media modules (winegstreamer: GStreamer, winedmo: ffmpeg) are left to the host's libraries: bundling them
# was ~100 MB of codecs, and Shapr3D plays no media. Where the host has them they load; where not, only media fails.
while IFS= read -r f; do elves+=("$f"); done < <(find "$app/usr/lib/wine/x86_64-unix" "$app/usr/lib/python$ver/lib-dynload" \
                                                   -name '*.so' ! -name winegstreamer.so ! -name winedmo.so)
python3 "$here/bundle_libs.py" "$rt/lib/x86_64-linux-gnu" "$app/usr/lib/bundled" \
  --also libgnutls.so.30 --also libusb-1.0.so.0 "${elves[@]}"

echo "STAGE Desktop integration"
install -m755 "$here/AppRun" "$app/AppRun"
install -m755 "$here/host-run" "$app/usr/bin/host-run"
ln -sf host-run "$app/usr/bin/xdg-open"
cp "$here/shapr3d-linux.svg" "$app/shapr3d-linux.svg"
ln -sf shapr3d-linux.svg "$app/.DirIcon"
sed -e 's/^Icon=.*/Icon=shapr3d-linux/' "$here/shapr3d-linux.desktop" > "$app/shapr3d-linux.desktop"

echo "STAGE Packing"
# release.sh names the file after the version and passes UPDATE_INFO (AppImageUpdate's
# "gh-releases-zsync|owner|repo|latest|pattern"); with it appimagetool embeds that and writes NAME.zsync beside it
name=${APPIMAGE_NAME:-shapr3d-linux-x86_64.AppImage}
upd=(); [ -n "${UPDATE_INFO:-}" ] && upd=(-u "$UPDATE_INFO")
(cd "$out" && ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$tool" --no-appstream "${upd[@]}" "$app" "$out/$name" >/dev/null)
echo "appimage: $out/$name ($(du -h "$out/$name" | cut -f1))"
