#!/bin/bash
# media.sh — waybar media helper for ardal-dotfiles
# Filters MPRIS players to find one actually Playing (not Paused/Stopped).
# This solves the "zombie player" problem where zen-browser keeps a Paused
# MPRIS registration forever after closing a YouTube tab.
#
# Usage (called by waybar custom modules):
#   media.sh check    → exit 0 if any player is Playing, exit 1 otherwise
#   media.sh text     → output "title - artist" of first Playing player
#   media.sh icon     → output 󰝚 (playing) — only useful when check passes
#
# Requires: playerctl, gawk (awk)
# Env: XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS must be set by waybar (they are).

case "${1:-check}" in
  check)
    # exit 0 if ANY player's status line is exactly "Playing"
    playerctl --all-players status 2>/dev/null | grep -qi "^Playing$" ;;
  text)
    # Find first Playing player and output "title - artist" (tab-separated parse)
    playerctl --all-players --format "{{status}}	{{title}}	{{artist}}" 2>/dev/null \
      | awk -F'\t' '$1 == "Playing" { print $2 " - " $3; exit }' ;;
  icon)
    echo "󰝚" ;;
  *)
    exit 1 ;;
esac