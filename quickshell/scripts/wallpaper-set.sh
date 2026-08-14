#!/usr/bin/env bash
#
# wallpaper-set.sh
#
# Sets the wallpaper via awww (renamed from swww in Oct 2025), extracts
# an accent color from the image with matugen, and writes it to color.txt
# for Bar.qml's FileView to pick up (watchChanges handles the live reload —
# no shell restart needed).
#
# Requires: awww, matugen, jq
#   awww:    https://codeberg.org/LGFae/awww  (Arch: pacman -S awww)
#   matugen: https://github.com/InioX/matugen
#
# Usage:
#   wallpaper-set.sh                 # pick a random wallpaper from WALLPAPER_DIR
#   wallpaper-set.sh /path/to/img    # set a specific wallpaper
#
# EDIT THESE PATHS for your system:

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
COLOR_FILE="${COLOR_FILE:-$HOME/color.txt}"          # must match colorFilePath in Bar.qml
STATE_DIR="${STATE_DIR:-$HOME/.local/state/wallshell}"
CURRENT_LINK="$STATE_DIR/current"

set -euo pipefail

mkdir -p "$STATE_DIR"

for bin in awww matugen jq; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "wallpaper-set: missing dependency '$bin'" >&2
        exit 1
    fi
done

# --- pick the wallpaper --------------------------------------------------

if [[ $# -ge 1 ]]; then
    WALLPAPER="$1"
else
    WALLPAPER=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        | shuf -n 1)
fi

if [[ -z "${WALLPAPER:-}" || ! -f "$WALLPAPER" ]]; then
    echo "wallpaper-set: no valid wallpaper found (looked in $WALLPAPER_DIR)" >&2
    exit 1
fi

# --- apply it with awww ---------------------------------------------------

if ! pgrep -x awww-daemon >/dev/null 2>&1; then
    awww-daemon &
    sleep 0.5
fi

awww img "$WALLPAPER" \
    --transition-type grow \
    --transition-duration 1 \
    --transition-fps 60

# --- remember current wallpaper (mirrors caelestia's state symlink) -----

ln -sf "$WALLPAPER" "$CURRENT_LINK"

# --- extract 4 colors with matugen and write color.txt -------------------
#
# scheme-fidelity keeps colors close to what's actually in the image,
# instead of matugen's default scheme-tonal-spot, which normalizes hues
# toward Material You's accessibility palette (why a red wallpaper was
# giving you lavender before).
#
# color.txt is written as KEY=VALUE lines:
#   BG=<background>       TEXT=<foreground>
#   ACTIVE=<accent for the focused workspace>
#   INACTIVE=<muted color for unfocused workspaces>

JSON=$(matugen image "$WALLPAPER" --json hex --mode dark \
    --source-color-index 0 --type scheme-fidelity 2>/dev/null)

if [[ -n "$JSON" ]]; then
    BG=$(echo "$JSON"   | jq -r '.colors.background.dark.color // empty')
    TEXT=$(echo "$JSON" | jq -r '.colors.on_background.dark.color // empty')
    ACTIVE=$(echo "$JSON"   | jq -r '.colors.primary.dark.color // empty')
    INACTIVE=$(echo "$JSON" | jq -r '.colors.surface_variant.dark.color // empty')
fi

if [[ -n "${BG:-}" && -n "${TEXT:-}" && -n "${ACTIVE:-}" && -n "${INACTIVE:-}" ]]; then
    {
        echo "BG=$BG"
        echo "TEXT=$TEXT"
        echo "ACTIVE=$ACTIVE"
        echo "INACTIVE=$INACTIVE"
    } > "$COLOR_FILE"
else
    echo "wallpaper-set: matugen extraction failed, color.txt left unchanged" >&2
fi

echo "$WALLPAPER"