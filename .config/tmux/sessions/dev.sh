#!/usr/bin/env bash
# /* ---- ardal dotfiles - tmux dev session ---- */  #
#
# Layout:
#   +-----------+-----------+
#   |   nvim    |  opencode |
#   +-----------+-----------+
#   |        terminal       |
#   +-----------------------+
#
# Usage:
#   tmux-dev                     # attach (or create if missing)
#   tmux-dev new                 # recreate session from scratch
#   tmux-dev <path>              # open nvim in <path>
#
# The session is called "dev". Re-running the script reuses the existing
# session (attach) unless you pass "new".

set -euo pipefail

SESSION="dev"
WORKDIR="${1:-$PWD}"
FORCE_NEW=0

if [[ "${1:-}" == "new" ]]; then
  FORCE_NEW=1
  WORKDIR="$PWD"
elif [[ -n "${1:-}" && -d "$1" ]]; then
  WORKDIR="$1"
fi

# Kill existing session if forced
if [[ "$FORCE_NEW" -eq 1 ]]; then
  tmux kill-session -t "$SESSION" 2>/dev/null || true
fi

# Attach to existing session if present
if tmux has-session -t "$SESSION" 2>/dev/null && [[ "$FORCE_NEW" -eq 0 ]]; then
  exec tmux attach -t "$SESSION"
fi

# Create detached session with a single window named "dev".
# Capture dynamic pane IDs via -P to avoid hardcoding pane indices
# (tmux.conf sets pane-base-index 1, and -f splits produce non-sequential
# numbering, so fixed indices are fragile).
TMUX_PANE_NEOVIM=$(tmux new-session -d -s "$SESSION" -n dev -c "$WORKDIR" -P -F '#{pane_id}')
tmux send-keys -t "$TMUX_PANE_NEOVIM" "cd '$WORKDIR' && nvim" C-m

# Split off the terminal at the bottom spanning the full width (-f).
TMUX_PANE_TERMINAL=$(tmux split-window -v -f -t "$TMUX_PANE_NEOVIM" -c "$WORKDIR" -P -F '#{pane_id}')

# Split the top pane (nvim) horizontally to get opencode on the right.
# -p 5 makes the new pane (opencode) 5% of the width, so nvim gets 95%.
TMUX_PANE_OPENCODE=$(tmux split-window -h -p 5 -t "$TMUX_PANE_NEOVIM" -c "$WORKDIR" -P -F '#{pane_id}')
tmux send-keys -t "$TMUX_PANE_OPENCODE" "cd '$WORKDIR' && opencode" C-m
# Pane layout: neovim (top-left, wide), opencode (top-right, narrow), terminal (bottom)

# Resize: terminal at bottom stays compact so the editor row dominates.
tmux resize-pane -t "$TMUX_PANE_TERMINAL" -y 1

# Focus the terminal pane so it's the default on attach
tmux select-pane -t "$TMUX_PANE_TERMINAL"

# Attach
tmux attach -t "$SESSION"
