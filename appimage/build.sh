#!/usr/bin/env bash
# Pack the Shapr3D for Linux AppImage from the freedesktop SDK build that flatpak/build.sh makes (run that first).
#
#   appimage/build.sh [OUTDIR]
#
# The SDK build is Wine, 7-Zip, the installer and wine-uwp's runtime, linked against the freedesktop runtime; the
# AppImage adds that runtime's Python (the setup tools need only its standard library) and the libraries hosts do not
# reliably have (bundle_libs.py), and the runtime's glibc for hosts older than it (bundle_glibc.sh), so the AppImage
# does not depend on the host's glibc version. The host provides its GPU drivers (GL, Vulkan), X11/Wayland,
# fontconfig/freetype, audio and D-Bus.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../env.sh"
files=${SDK_BUILD:-$UWP_BIN/sdk-build}/build/files
[ -x "$files/bin/wine" ] || { echo "no SDK build at $files (run flatpak/build.sh first)" >&2; exit 1; }

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
rm -rf "$app/usr"/{manifest.json,share/app-info,share/runtime,share/applications,share/metainfo,share/icons,lib/debug}

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

echo "STAGE Bundling glibc"
patchelf=$UWP_BIN/tools/patchelf
[ -x "$patchelf" ] || { mkdir -p "$(dirname "$patchelf")"
  curl -sfL https://github.com/NixOS/patchelf/releases/download/0.18.0/patchelf-0.18.0-x86_64.tar.gz |
    tar -xzO ./bin/patchelf > "$patchelf.tmp" && chmod +x "$patchelf.tmp" && mv "$patchelf.tmp" "$patchelf"; }
PATCHELF=$patchelf "$here/bundle_glibc.sh" "$app" "$rt/lib/x86_64-linux-gnu"

echo "STAGE Desktop integration"
install -m755 "$here/AppRun" "$app/AppRun"
install -m755 "$here/host-run" "$app/usr/bin/host-run"
ln -sf host-run "$app/usr/bin/xdg-open"
cp "$here/../flatpak/io.github.designgears.Shapr3DLinux.svg" "$app/shapr3d-linux.svg"
ln -sf shapr3d-linux.svg "$app/.DirIcon"
sed -e 's/^Icon=.*/Icon=shapr3d-linux/' "$here/../flatpak/io.github.designgears.Shapr3DLinux.desktop" > "$app/shapr3d-linux.desktop"

echo "STAGE Packing"
# release.sh names the file after the version and passes UPDATE_INFO (AppImageUpdate's
# "gh-releases-zsync|owner|repo|latest|pattern"); with it appimagetool embeds that and writes NAME.zsync beside it
name=${APPIMAGE_NAME:-shapr3d-linux-x86_64.AppImage}
upd=(); [ -n "${UPDATE_INFO:-}" ] && upd=(-u "$UPDATE_INFO")
(cd "$out" && ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$tool" --no-appstream "${upd[@]}" "$app" "$out/$name" >/dev/null)
echo "appimage: $out/$name ($(du -h "$out/$name" | cut -f1))"
