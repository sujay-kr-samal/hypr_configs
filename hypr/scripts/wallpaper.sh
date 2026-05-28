#!/usr/bin/env bash

# =========================================================
# HYPRLAND WALLPAPER SCRIPT
# awww + PYWAL + WAYBAR + KITTY
# =========================================================

set -euo pipefail

# =========================================================
# ENVIRONMENT
# =========================================================

export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"

export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"

# =========================================================
# CONFIG
# =========================================================

WALLPAPER_DIR="$HOME/Pictures/wallpapers"

CACHE_DIR="$HOME/.cache/wallpaper"
CACHE_FILE="$CACHE_DIR/current"

WAYBAR_DIR="$HOME/.config/waybar"
WAYBAR_COLORS="$WAYBAR_DIR/colors.css"

mkdir -p "$CACHE_DIR"
mkdir -p "$WAYBAR_DIR"

# =========================================================
# START awww
# Kill any running or zombie daemon, wipe ALL stale sockets
# (regardless of path), then start fresh.
# This avoids the "socket already in use" panic on crash.
# =========================================================

if ! pgrep -x awww-daemon >/dev/null; then
    /usr/bin/awww-daemon >/dev/null 2>&1 &
    sleep 1
fi

# =========================================================
# WALLPAPER LIST
# =========================================================

mapfile -t WALLPAPERS < <(
    find "$WALLPAPER_DIR" -type f \
    \( -iname "*.jpg" \
    -o -iname "*.jpeg" \
    -o -iname "*.png" \
    -o -iname "*.webp" \) | sort
)

COUNT=${#WALLPAPERS[@]}

# Guard against empty wallpaper directory
if [ "$COUNT" -eq 0 ]; then
    echo "Error: No wallpapers found in $WALLPAPER_DIR"
    exit 1
fi

# =========================================================
# HELPERS
# =========================================================

get_current() {
    [ -f "$CACHE_FILE" ] && cat "$CACHE_FILE"
}

get_index() {
    local CURRENT="$1"

    for i in "${!WALLPAPERS[@]}"; do
        if [ "${WALLPAPERS[$i]}" = "$CURRENT" ]; then
            echo "$i"
            return
        fi
    done

    echo 0
}

get_next() {
    local IDX
    IDX=$(get_index "$(get_current)")
    echo "${WALLPAPERS[$(( (IDX + 1) % COUNT ))]}"
}

get_prev() {
    local IDX
    IDX=$(get_index "$(get_current)")
    echo "${WALLPAPERS[$(( (IDX - 1 + COUNT) % COUNT ))]}"
}

# Use /dev/urandom for uniform distribution (avoids $RANDOM % COUNT bias)
get_random() {
    local RAND
    RAND=$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')
    echo "${WALLPAPERS[$(( RAND % COUNT ))]}"
}

# =========================================================
# GENERATE WAYBAR COLORS
# =========================================================

generate_waybar_colors() {
    # Source in a subshell to avoid polluting the parent environment.
    # set +u because pywal's colors.sh may contain unset variables
    # (e.g. FZF_DEFAULT_OPTS) that would trip -u and abort the script.
    (
        set +u
        # shellcheck source=/dev/null
        source "$HOME/.cache/wal/colors.sh"

        cat > "$WAYBAR_COLORS" << CSSEOF
@define-color background ${background};
@define-color foreground ${foreground};

@define-color color0 ${color0};
@define-color color1 ${color1};
@define-color color2 ${color2};
@define-color color3 ${color3};
@define-color color4 ${color4};
@define-color color5 ${color5};
@define-color color6 ${color6};
@define-color color7 ${color7};

@define-color color8 ${color8};
@define-color color9 ${color9};
@define-color color10 ${color10};
@define-color color11 ${color11};
@define-color color12 ${color12};
@define-color color13 ${color13};
@define-color color14 ${color14};
@define-color color15 ${color15};
CSSEOF
    )
}

# =========================================================
# RELOAD WAYBAR
# =========================================================

reload_waybar() {
    cp "$WAYBAR_COLORS" "$WAYBAR_COLORS.prev" 2>/dev/null || true
    sleep 0.5

    local PID
    PID=$(pgrep -x waybar | head -n1) || true

    if [ -n "$PID" ]; then
        kill -SIGUSR2 "$PID" || true
        echo ">> Waybar reloaded (PID $PID)"
    else
        echo ">> Waybar not running, skipping reload"
    fi

    echo ">> Waybar colors written"
}

# =========================================================
# RELOAD KITTY
# =========================================================

reload_kitty() {
    local PID
    PID=$(pgrep -x kitty | head -n1) || true

    if [ -n "$PID" ]; then
        kill -SIGUSR2 "$PID" || true
        echo ">> Kitty reloaded (PID $PID)"
    else
        echo ">> Kitty not running, skipping reload"
    fi
}
# =====================================================
# GENERATE ROFI COLORS (from pywal)
# =====================================================

generate_rofi_colors() {
    (
    set +u
    source "$HOME/.cache/wal/colors.sh"
    mkdir -p "$HOME/.config/rofi/wallust"
    cat > "$HOME/.config/rofi/wallust/colors-rofi.rasi" << EOF
* {
    wal-background:     ${color0};
    wal-background-alt: ${color8};
    wal-foreground:     ${color7};
    wal-selected:       ${color4};
    wal-active:         ${color2};
    wal-urgent:         ${color1};
    wal-text-selected:  ${color0};
    wal-text-color:     ${color7};
}
EOF
    )
}
# =========================================================
# APPLY WALLPAPER
# =========================================================

apply_wallpaper() {

    local WALL="$1"

    if [ ! -f "$WALL" ]; then
        echo "Error: Wallpaper not found: $WALL"
        exit 1
    fi

    # =====================================================
    # SET WALLPAPER
    # =====================================================

    /usr/bin/awww img "$WALL" \
        --transition-type grow \
        --transition-duration 1 \
        --transition-fps 60 \
        >/dev/null 2>&1

    # =====================================================
    # GENERATE PYWAL COLORS
    # =====================================================

    /usr/bin/wal -i "$WALL" -n >/dev/null 2>&1

    # =====================================================
    # WAIT FOR WAL (with timeout ~5s)
    # =====================================================

    local WAIT=0
    while [ ! -f "$HOME/.cache/wal/colors.sh" ]; do
        sleep 0.1
        WAIT=$((WAIT + 1))
        if [ "$WAIT" -gt 50 ]; then
            echo "Error: Timed out waiting for wal to generate colors.sh"
            exit 1
        fi
    done

    # =====================================================
    # GENERATE WAYBAR COLORS
    # =====================================================

    generate_waybar_colors

    # =====================================================
    # GENERATE ROFI COLORS
    # =====================================================

    generate_rofi_colors

    # =====================================================
    # SAVE CURRENT WALLPAPER
    # =====================================================

    echo "$WALL" > "$CACHE_FILE"

    # =====================================================
    # RELOAD APPS
    # =====================================================

    reload_kitty
    reload_waybar
}

# =========================================================
# COMMANDS
# =========================================================

case "${1:-random}" in

    next)
        apply_wallpaper "$(get_next)"
        ;;

    prev)
        apply_wallpaper "$(get_prev)"
        ;;

    random)
        apply_wallpaper "$(get_random)"
        ;;

    current)
        if [ -f "$CACHE_FILE" ]; then
            apply_wallpaper "$(cat "$CACHE_FILE")"
        else
            apply_wallpaper "$(get_random)"
        fi
        ;;

    use)
        if [ -z "${2:-}" ]; then
            echo "Usage: wallpaper.sh use <path>"
            exit 1
        fi
        apply_wallpaper "$2"
        ;;

    *)
        echo "Usage:"
        echo "  wallpaper.sh random"
        echo "  wallpaper.sh next"
        echo "  wallpaper.sh prev"
        echo "  wallpaper.sh current"
        echo "  wallpaper.sh use <path>"
        ;;
esac