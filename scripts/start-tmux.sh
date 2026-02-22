#!/usr/bin/env bash
# start-tmux.sh -- Launch claude-self-reborn inside a tmux session
#
# Usage:
#   ./scripts/start-tmux.sh [session-name]
#
# Creates a tmux session running the self-reborn wrapper.
# Detach with Ctrl-b d, reattach with: tmux attach -t <session-name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SESSION_NAME="${1:-claude-reborn}"

# Check tmux
if ! command -v tmux &>/dev/null; then
    echo "Error: tmux is required but not installed."
    exit 1
fi

# Check if session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Session '$SESSION_NAME' already exists. Attaching..."
    tmux attach-session -t "$SESSION_NAME"
    exit 0
fi

# Make wrapper executable
chmod +x "$SCRIPT_DIR/claude-self-reborn.sh"

# Create new tmux session with the wrapper
tmux new-session -d -s "$SESSION_NAME" -c "$PROJECT_DIR" \
    "$SCRIPT_DIR/claude-self-reborn.sh $PROJECT_DIR"

echo "tmux session '$SESSION_NAME' created."
echo "  Attach:  tmux attach -t $SESSION_NAME"
echo "  Detach:  Ctrl-b d (inside session)"
echo "  Kill:    tmux kill-session -t $SESSION_NAME"
echo ""
echo "Attaching now..."
tmux attach-session -t "$SESSION_NAME"
