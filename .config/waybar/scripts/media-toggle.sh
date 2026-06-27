#!/bin/bash
# media-toggle.sh — toggle the GTK4 media-center popup visibility.
#
# Bound to Super+M in hyprland.conf. First call launches the popup (which
# starts hidden waiting for a Playing track); subsequent calls send SIGUSR1
# to toggle visibility. If the process died, relaunch it.
#
# Requires: playerctl, python-gobject, gtk4, gtk4-layer-shell.
#
# CRITICAL: when Hyprland binds this script, the env passed is minimal —
# WAYLAND_DISPLAY, DBUS_SESSION_BUS_ADDRESS and HYPRLAND_INSTANCE_SIGNATURE
# are NOT inherited. Without them:
#   - gtk4-layer-shell can't anchor the window -> opens as a normal toplevel
#     (appears in taskbar, focuses, looks like an app instead of a popup)
#   - playerctl can't reach the session bus -> "no player" + inert buttons
# So we force-resolve them from XDG_RUNTIME_DIR (which Hyprland does set).

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
# Hyprland instance signature (needed only if the script ever calls hyprctl)
for sig in "$XDG_RUNTIME_DIR"/hypr/*; do
  [ -d "$sig" ] || continue
  export HYPRLAND_INSTANCE_SIGNATURE="${sig##*/}"
  break
done

PIDFILE="$XDG_RUNTIME_DIR/media-center.pid"
SCRIPT="$HOME/.config/waybar/scripts/media-center.py"

if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE" 2>/dev/null)
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    # live — toggle visibility
    kill -USR1 "$PID"
    exit 0
  fi
fi

# gtk4-layer-shell MUST be preloaded before libwayland-client for layer init to work.
# See: https://github.com/wmww/gtk4-layer-shell/blob/main/linking.md
export LD_PRELOAD="/usr/lib/libgtk4-layer-shell.so${LD_PRELOAD:+:$LD_PRELOAD}"

# not running (or stale pidfile) — launch fresh with the full env we just exported
nohup python3 "$SCRIPT" >/tmp/media-center.log 2>&1 &
echo $! > "$PIDFILE"
disown