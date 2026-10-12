#!/usr/bin/env bash
# Does a built AppImage set up and start Shapr3D from nothing? The command-line half of what the installer does, in
# an empty data directory, on a private Xvfb display:
#
#   appimage/smoke.sh APPIMAGE OUTDIR
#
#   SMOKE_ISO       a Windows 11 ISO to harvest (what the installer downloads), or
#   SMOKE_WINDOWS   an already harvested tree, copied in instead - quicker, but skips the harvest
#   SMOKE_PACKAGE   the Shapr3D .msixbundle to install
#
# Passes when Shapr3D's window shows real UI (its first screen, sign-in on a fresh install) and stays up. Writes
# OUTDIR/smoke.png and OUTDIR/smoke.log. The data directory is deleted afterwards.
set -euo pipefail
img=$(realpath "$1"); out=$(realpath -m "$2"); mkdir -p "$out"
: "${SMOKE_PACKAGE:?set SMOKE_PACKAGE to a Shapr3D .msixbundle}"
[ -n "${SMOKE_ISO:-}" ] || [ -n "${SMOKE_WINDOWS:-}" ] || { echo "set SMOKE_ISO or SMOKE_WINDOWS" >&2; exit 2; }
data=$(mktemp -d "${TMPDIR:-/tmp}/shapr3d-smoke.XXXXXX")
disp=:${SMOKE_DISPLAY:-91}
log=$out/smoke.log; : > "$log"

# everything the AppImage starts carries WINEPREFIX=$data/prefix; that is how it is found and stopped
stop_all() {
  local e p
  for e in /proc/[0-9]*/environ; do
    p=${e#/proc/}; p=${p%/environ}
    tr '\0' '\n' 2>/dev/null < "$e" | grep -qxF "WINEPREFIX=$data/prefix" && kill -9 "$p" 2>/dev/null
  done
  return 0
}
cleanup() { stop_all; sleep 1; [ -n "${xvfb:-}" ] && kill "$xvfb" 2>/dev/null; rm -rf "$data"; }
trap cleanup EXIT
Xvfb "$disp" -screen 0 1600x1000x24 -nolisten tcp >/dev/null 2>&1 & xvfb=$!
sleep 1
run() { env -u WAYLAND_DISPLAY DISPLAY="$disp" WINE_UWP_DATA="$data" WINE_UWP_LAUNCHER=log "$img" "$@" >> "$log" 2>&1; }

echo "smoke: harvest"
if [ -n "${SMOKE_ISO:-}" ]; then run harvest "$SMOKE_ISO"; else cp -a --reflink=auto "$SMOKE_WINDOWS" "$data/windows"; fi
echo "smoke: new-prefix"; run new-prefix
echo "smoke: install"; run install "$SMOKE_PACKAGE"
echo "smoke: run"; (run run &)

# the window, then real UI: a fresh install's first screen has a few hundred colours, a blank window one
shot() { DISPLAY=$disp xwd -id "$1" -silent 2>/dev/null | magick xwd:- "$out/smoke.png" 2>/dev/null; }
ok=; seen=0
for i in $(seq 120); do
  sleep 1
  w=$(DISPLAY=$disp xdotool search --onlyvisible --name '^Shapr3D$' 2>/dev/null | head -1) || true
  [ -n "$w" ] || continue
  shot "$w" || continue
  k=$(identify -format %k "$out/smoke.png" 2>/dev/null || echo 0)
  if [ "$k" -ge 100 ]; then seen=$((seen + 1)); else seen=0; fi
  [ $seen -ge 5 ] && { ok=1; break; }
done
if [ -n "$ok" ]; then echo "smoke: PASS ($k colours after ${i}s; $out/smoke.png)"; exit 0; fi
echo "smoke: FAIL (no Shapr3D UI within 120 s; see $log and $out/smoke.png)" >&2
exit 1
