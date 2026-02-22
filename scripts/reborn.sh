#!/bin/bash
# reborn.sh -- Claude Code restart executor
#
# Runs in a separate tmux window. Stops the current Claude Code process,
# then restarts it with --resume in the original pane.
#
# Usage (called by Claude via /reload skill):
#   tmux new-window -n reborn "./scripts/reborn.sh <tmux-pane> <session-id> <project-dir>"
#
# Arguments:
#   $1  tmux pane target (e.g., "%3" or "mysession:0.0")
#   $2  Claude session ID to resume
#   $3  project directory (absolute path)

set -eo pipefail

TARGET_PANE="$1"
SESSION_ID="$2"
PROJECT_DIR="$3"
HANDOFF_FILE="$PROJECT_DIR/.claude/self-reborn/handoff.md"

if [[ -z "$TARGET_PANE" || -z "$SESSION_ID" || -z "$PROJECT_DIR" ]]; then
    echo "Usage: reborn.sh <tmux-pane> <session-id> <project-dir>"
    echo "  tmux-pane:   target pane (e.g., %3)"
    echo "  session-id:  Claude session ID to resume"
    echo "  project-dir: absolute path to project"
    exit 1
fi

log() {
    echo "[reborn] $(date '+%H:%M:%S') $1"
}

log "Starting restart sequence"
log "  Target pane: $TARGET_PANE"
log "  Session ID:  $SESSION_ID"
log "  Project dir: $PROJECT_DIR"

# --- Step a: Wait briefly, then send Ctrl+C to stop Claude ---
log "Waiting 2s before stopping Claude..."
sleep 2

log "Sending Ctrl+C to $TARGET_PANE"
tmux send-keys -t "$TARGET_PANE" C-c

# --- Step b: Wait for Claude to actually stop ---
log "Waiting for Claude to exit..."
MAX_WAIT=30
waited=0
while [[ $waited -lt $MAX_WAIT ]]; do
    sleep 1
    waited=$((waited + 1))

    # Check if pane is at a shell prompt (no foreground process besides shell)
    # tmux's pane_current_command shows the foreground process
    fg_cmd=$(tmux display-message -t "$TARGET_PANE" -p '#{pane_current_command}' 2>/dev/null || echo "")

    # Shell names indicate Claude has exited
    case "$fg_cmd" in
        bash|zsh|sh|fish)
            log "Claude exited (shell prompt detected after ${waited}s)"
            break
            ;;
    esac

    # Also send another Ctrl+C if stuck (after 5s and 15s)
    if [[ $waited -eq 5 || $waited -eq 15 ]]; then
        log "Still running ($fg_cmd), sending another Ctrl+C..."
        tmux send-keys -t "$TARGET_PANE" C-c
    fi
done

if [[ $waited -ge $MAX_WAIT ]]; then
    log "WARNING: Claude did not exit within ${MAX_WAIT}s. Attempting kill..."
    # Get the pane's child process and kill it
    pane_pid=$(tmux display-message -t "$TARGET_PANE" -p '#{pane_pid}')
    if [[ -n "$pane_pid" ]]; then
        # Kill child processes (Claude) but not the shell itself
        pkill -TERM -P "$pane_pid" -f "claude" 2>/dev/null || true
        sleep 2
    fi
fi

# --- Step c: Resume Claude with --resume ---
log "Starting Claude with --resume $SESSION_ID"
sleep 1

# Build the claude command
claude_cmd="cd '$PROJECT_DIR' && claude --resume '$SESSION_ID'"
tmux send-keys -t "$TARGET_PANE" "$claude_cmd" Enter

# --- Step d: Wait for Claude to be ready, then send initial prompt ---
log "Waiting for Claude to start..."
sleep 8

if [[ -f "$HANDOFF_FILE" ]]; then
    log "Sending handoff prompt..."
    tmux send-keys -t "$TARGET_PANE" "前回のセッションからの再起動です。.claude/self-reborn/handoff.md を読んで、再起動理由と次のステップを確認して作業を続けてください。" Enter
    log "Handoff prompt sent"
else
    log "No handoff.md found, Claude will resume without context"
fi

# --- Step e: Self-cleanup ---
log "Restart complete. Closing this window in 3s..."
sleep 3
# tmux window will close when this script exits
