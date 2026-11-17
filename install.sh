#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.config/DankMaterialShell/plugins/wallpaperWeather"

mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
mkdir -p "$DEST"
cp -a "$SRC_DIR"/. "$DEST"/
rm -f "$DEST/install.sh"

echo "Installed Wallpaper Weather v5 to: $DEST"

if command -v dms >/dev/null 2>&1; then
    dms ipc plugin-scan rescan wallpaperWeather >/dev/null 2>&1 || dms ipc plugin-scan scan >/dev/null 2>&1 || true
    echo
    echo "Plugin status:"
    dms ipc plugin-scan status wallpaperWeather || true
fi

echo
echo "Enable Wallpaper Weather, then add 'Wallpaper Weather' to a DankBar section."
