#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

selection=$(find "$WALLPAPER_DIR" \
    -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    -print0 \
    | sort -z \
    | while IFS= read -r -d '' fullpath; do
        basename=$(basename "$fullpath")
        printf '%s\x00icon\x1f%s\n' "$basename" "$fullpath"
    done \
    | rofi -dmenu -i -show-icons \
        -config "$HOME/.config/rofi/config-wallpaper.rasi" \
        -p "Wallpaper")

# Empty selection means the user cancelled rofi.
if [[ -z "$selection" ]]; then
    exit 0
fi

# rofi returns the entry label (the basename); resolve it back to the full path.
fullpath="$WALLPAPER_DIR/$selection"

if [[ ! -f "$fullpath" ]]; then
    echo "wallpaper-menu: selected file not found: $fullpath" >&2
    exit 1
fi

awww img "$fullpath" --transition-type fade --transition-duration 1
