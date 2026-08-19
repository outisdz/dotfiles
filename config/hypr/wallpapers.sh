#!/bin/bash

WALLPAPER_DIR="$HOME/wallpapers"
RANDOM_IMG=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | shuf -n 1)
CONFIG="$HOME/.config/hypr/hyprpaper.conf"

cat > "$CONFIG" <<EOF
preload = $RANDOM_IMG

wallpaper {
    monitor = LVDS-1
    path = $RANDOM_IMG
    timeout = 300
}
splash = false
EOF
