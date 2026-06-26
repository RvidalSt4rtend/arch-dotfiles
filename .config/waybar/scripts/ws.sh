#!/bin/bash
# ws.sh — Muestra el workspace para un slot (1-5) dependiendo de la página activa
# Página 1 (ws activo <=5): slot 1→1, 2→2, …, 5→5
# Página 2 (ws activo 6-10): slot 1→6, 2→7, …, 5→10

slot=$1
active=$(hyprctl activeworkspace -j 2>/dev/null | jq '.id' 2>/dev/null || echo 1)

if [ "$active" -ge 6 ] 2>/dev/null && [ "$active" -le 10 ] 2>/dev/null; then
    ws=$((slot + 5))
else
    ws=$slot
fi

# "0" para el workspace 10
[ "$ws" -eq 10 ] && display="0" || display="$ws"

# Estado del workspace
current_id=$(hyprctl activeworkspace -j 2>/dev/null | jq '.id' 2>/dev/null || echo 1)
windows=$(hyprctl workspaces -j 2>/dev/null | jq ".[] | select(.id == $ws) | .windows" 2>/dev/null)

if [ "$ws" = "$current_id" ] 2>/dev/null; then
    class="active"
    echo "{\"text\": \"<span foreground='#00c8c8'><b>$display</b></span>\", \"class\": \"$class\"}"
elif [ -n "$windows" ] && [ "$windows" -gt 0 ] 2>/dev/null; then
    class="occupied"
    echo "{\"text\": \"<span foreground='#cccccc'>$display</span>\", \"class\": \"$class\"}"
else
    class="empty"
    echo "{\"text\": \"<span foreground='#555555'>$display</span>\", \"class\": \"$class\"}"
fi
