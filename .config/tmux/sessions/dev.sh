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
# Pane 0 starts as nvim.
tmux new-session -d -s "$SESSION" -n dev -c "$WORKDIR"
tmux send-keys -t "$SESSION:dev.0" "cd '$WORKDIR' && nvim" C-m

# Split off the terminal at the bottom spanning the full width (-f).
# This creates pane 1 below pane 0 covering the entire width.
tmux split-window -v -f -t "$SESSION:dev.0" -c "$WORKDIR"
# Now: pane 0 = nvim (top), pane 1 = terminal (bottom, full width)

# Split the top pane (nvim) horizontally to get opencode on the right.
# Use -t to target the top pane explicitly. After the -f split, pane 0 is
# still the top one; splitting it -h produces a new pane to its right.
tmux select-pane -t "$SESSION:dev.0"
tmux split-window -h -t "$SESSION:dev.0" -c "$WORKDIR"
tmux send-keys -t "$SESSION:dev.1" "cd '$WORKDIR' && opencode" C-m
# Pane layout now: 0=nvim (top-left), 1=opencode (top-right), 2=terminal (bottom)

# Resize: top row ~70%, terminal ~30%
tmux resize-pane -t "$SESSION:dev.2" -y 6

# Focus the terminal pane so it's the default on attach
tmux select-pane -t "$SESSION:dev.2"

# Attach
tmux attach -t "$SESSION"
