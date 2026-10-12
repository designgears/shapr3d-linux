# Sourced by every build script here. Shapr3D for Linux is built on a wine-uwp checkout: WINE_UWP points at it
# (default: ../wine-uwp beside this repo), and its env.sh gives UWP_BIN (where builds go) and the Wine build.
SHAPR3D_LINUX=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WINE_UWP=${WINE_UWP:-$(cd "$SHAPR3D_LINUX/../wine-uwp" 2>/dev/null && pwd)}
[ -f "$WINE_UWP/env.sh" ] || { echo "no wine-uwp checkout at '${WINE_UWP}' (set WINE_UWP)" >&2; return 1 2>/dev/null || exit 1; }
. "$WINE_UWP/env.sh"
export SHAPR3D_LINUX WINE_UWP
