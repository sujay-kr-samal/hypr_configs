#!/usr/bin/env bash
source "$HOME/.cache/wal/colors.sh"

hex2rgb() {
    local h="${1#'#'}"
    python3 -c "h='$h'; print(','.join(str(int(h[i:i+2],16)) for i in (0,2,4)))"
}

BG=$(hex2rgb "$background")
C8=$(hex2rgb "$color8")

cat > "$HOME/.config/eww/eww.scss" << SCSS
window {
  background: transparent;
  background-color: transparent;
}
.background {
  background: transparent;
  background-color: transparent;
}
* {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 13px;
  color: ${foreground};
}
.dashboard {
  background: transparent;
  padding: 12px;
}
.date {
  font-size: 18px;
  font-weight: bold;
  color: ${foreground};
  margin-bottom: 6px;
  padding-left: 4px;
}
.card {
  background: rgba(${BG}, 0.82);
  border-radius: 14px;
  padding: 12px;
  border: 1px solid rgba(${C8}, 0.3);
}
.card-title {
  font-size: 12px;
  color: ${color4};
  font-weight: bold;
  margin-bottom: 4px;
}
.card-val {
  font-size: 14px;
  color: ${foreground};
}
.card-sub {
  font-size: 11px;
  color: ${color8};
}
.stat-card {
  min-width: 60px;
}
.stat-icon {
  font-size: 20px;
  color: ${color4};
}
.stat-val {
  font-size: 13px;
  color: ${foreground};
}
.music-title {
  color: ${color2};
}
.row {
  margin-bottom: 4px;
}
.clock-box {
  background: transparent;
  padding: 10px;
}
.clock-time {
  font-size: 72px;
  font-weight: bold;
  color: ${foreground};
  letter-spacing: -2px;
}
.clock-day {
  font-size: 28px;
  font-style: italic;
  color: ${color7};
  margin-top: -8px;
}
.clock-date {
  font-size: 14px;
  color: ${color8};
  letter-spacing: 2px;
}
SCSS

if pgrep -x eww >/dev/null; then
    eww reload
    echo ">> EWW colors updated"
fi
