#!/usr/bin/env bash
# An installed Shapr3D for Linux tree on the host: wine-uwp's (packaging/build-dist.sh in the wine-uwp checkout:
# Wine, the scripts, the shims) plus this repo's installer as bin/wine-uwp-installer, which `wine-uwp setup` runs.
# For development and testing on this machine; the release AppImage is built in the freedesktop SDK instead
# (appimage/build.sh).
#
#   ./build-dist.sh OUT
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/env.sh"
out=$(realpath -m "$1")
"$WINE_UWP/packaging/build-dist.sh" "$out" | grep -v '^STAGE Done'
echo "STAGE Building the installer"
cargo build --release --quiet --manifest-path "$here/installer/Cargo.toml"
install -m755 "$here/installer/target/release/wine-uwp-installer" "$out/bin/"
git -C "$here" rev-parse --short HEAD 2>/dev/null > "$out/share/wine-uwp/SHAPR3D_LINUX_VERSION" || true
echo "STAGE Done: $out ($(du -sh "$out" | cut -f1))"
