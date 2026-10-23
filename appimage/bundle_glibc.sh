#!/usr/bin/env bash
# Bundle the runtime's glibc into an AppDir, for hosts older than it.
#
#   appimage/bundle_glibc.sh APPDIR RUNTIME_LIBDIR
#
# Everything in the AppImage is built against the freedesktop runtime's glibc, which is newer than the oldest
# distributions still supported. A program can only use a newer glibc through a matching dynamic loader, and the
# loader is named by an absolute path in the program (PT_INTERP). So every bundled executable is pointed at
# /tmp/.wine-uwp-glibc-ID/ld-linux-x86-64.so.2, with that directory as its RPATH (an executable's DT_RPATH also
# covers libraries dlopen()ed later, the host's GPU drivers included, so libm and friends cannot come from the host).
# libstdc++ and libgcc_s go with it: an old host's are older than the runtime's, which 7-Zip needs.
# AppRun fills that directory at start-up:
#   - host glibc older than ours: a copy of our loader and libraries (a copy, not links into the AppImage's mount,
#     so that it outlives the mount and serves every user of the machine);
#   - host glibc as new or newer: only a link to the host's loader, so the host's own glibc is used, as the host's
#     GPU drivers expect.
# glibc stays out of LD_LIBRARY_PATH: host programs (bash, xdg-open, a browser) would load it with their own loader.
set -euo pipefail
app=$1 rt=$2
PATCHELF=${PATCHELF:-patchelf}
dest=$app/usr/lib/glibc
mkdir -p "$dest"
for l in ld-linux-x86-64.so.2 libc.so.6 libm.so.6 libmvec.so.1 libpthread.so.0 libdl.so.2 librt.so.1 libresolv.so.2 \
         libutil.so.1 libanl.so.1 libnss_files.so.2 libnss_dns.so.2 libnss_compat.so.2 \
         libstdc++.so.6 libgcc_s.so.1; do
  cp "$(readlink -f "$rt/$l")" "$dest/$l"
done
ver=$("$dest/ld-linux-x86-64.so.2" --version | sed -n '1s/.* version \([0-9.]*\)\.$/\1/p')
[ -n "$ver" ] || { echo "cannot read the bundled glibc's version" >&2; exit 1; }
id=$(cat "$dest"/* | sha256sum | cut -c1-12)
echo "$ver" > "$dest/VERSION"
echo "$id" > "$dest/ID"
dir=/tmp/.wine-uwp-glibc-$id
n=0
while IFS= read -r f; do
  readelf -lW "$f" 2>/dev/null | grep -q 'Requesting program interpreter' || continue
  "$PATCHELF" --set-interpreter "$dir/ld-linux-x86-64.so.2" "$f"
  old=$("$PATCHELF" --print-rpath "$f")
  "$PATCHELF" --force-rpath --set-rpath "$dir${old:+:$old}" "$f"
  n=$((n+1))
done < <(find "$app/usr/bin" "$app/usr/lib/wine" -type f -perm -u+x)
echo "glibc $ver bundled ($id), $n executables pointed at $dir"
