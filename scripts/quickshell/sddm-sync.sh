#!/usr/bin/env bash

SDDM_BG="/usr/share/sddm/themes/pixie/assets/background.jpg"
LAST=""

while true; do
    CURRENT=$(awww query 2>/dev/null | grep -o '/home/.*/Pictures/Wallpapers/[^ ]*')
    
    if [[ -n "$CURRENT" && "$CURRENT" != "$LAST" ]]; then
        EXT="${CURRENT##*.}"
        if [[ "${EXT,,}" =~ ^(jpg|jpeg|png)$ ]]; then
            sudo cp "$CURRENT" "$SDDM_BG"
            LAST="$CURRENT"
        fi
    fi
    
    sleep 2
done