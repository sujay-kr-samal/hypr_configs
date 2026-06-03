#!/bin/bash
cat ~/.config/waybar/colors.css ~/.config/wlogout/style.css > /tmp/wlogout-merged.css
wlogout -s /tmp/wlogout-merged.css
