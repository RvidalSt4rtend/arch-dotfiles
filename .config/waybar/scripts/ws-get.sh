#!/bin/bash
# ws-get.sh — Devuelve el número de workspace real para un slot (1-5)
# Se evalúa en el momento del click, así que respeta la página actual.

slot=$1
active=$(hyprctl activeworkspace -j 2>/dev/null | jq '.id' 2>/dev/null || echo 1)

if [ "$active" -ge 6 ] 2>/dev/null && [ "$active" -le 10 ] 2>/dev/null; then
    echo $((slot + 5))
else
    echo "$slot"
fi
