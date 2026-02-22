#!/bin/bash
# claude-self-reborn.sh -- Claude Code self-restart wrapper
#
# Runs Claude Code inside a restart loop. When Claude sends SIGHUP to its
# parent (exit code 129), the wrapper restarts it with --resume to continue
# the session. Designed for self-improvement loops.
#
# Usage:
#   ./scripts/claude-self-reborn.sh [project-dir]
#   ./scripts/claude-self-reborn.sh              # uses current directory
#
# Environment:
#   CLAUDE_SELF_REBORN_MAX_CRASHES  max consecutive crashes before abort (default: 5)
#   CLAUDE_SELF_REBORN_BACKOFF      initial backoff seconds after crash (default: 2)
#   CLAUDE_SELF_REBORN_STATE_DIR    state directory (default: .claude/self-reborn)

set -eo pipefail

PROJECT_DIR="${1:-$(pwd)}"
STATE_DIR="${PROJECT_DIR}/${CLAUDE_SELF_REBORN_STATE_DIR:-.claude/self-reborn}"
MAX_CRASHES="${CLAUDE_SELF_REBORN_MAX_CRASHES:-5}"
INITIAL_BACKOFF="${CLAUDE_SELF_REBORN_BACKOFF:-2}"

# Ensure state directory exists
mkdir -p "$STATE_DIR"

# State files
SESSION_FILE="$STATE_DIR/session_id"
RESTART_REASON_FILE="$STATE_DIR/restart_reason"
CRASH_COUNT_FILE="$STATE_DIR/crash_count"
LOG_FILE="$STATE_DIR/restart.log"

log() {
    local msg="$(date '+%Y-%m-%d %H:%M:%S') $1"
    echo "$msg" | tee -a "$LOG_FILE"
}

# Initialize crash counter
if [[ ! -f "$CRASH_COUNT_FILE" ]]; then
    echo 0 > "$CRASH_COUNT_FILE"
fi

log "claude-self-reborn started. project=$PROJECT_DIR"

while true; do
    crash_count=$(cat "$CRASH_COUNT_FILE")

    # Build claude command
    claude_args=()

    # Resume session if we have a saved session ID
    if [[ -f "$SESSION_FILE" ]]; then
        saved_id=$(cat "$SESSION_FILE")
        if [[ -n "$saved_id" ]]; then
            claude_args+=(--resume "$saved_id")
            log "Resuming session: $saved_id"
        fi
    fi

    # Restart reason is NOT passed via -p (incompatible with --resume).
    # Instead, the SessionStart hook reads .claude/self-reborn/restart_reason
    # and injects it via additionalContext.
    if [[ -f "$RESTART_REASON_FILE" ]]; then
        reason=$(cat "$RESTART_REASON_FILE")
        if [[ -n "$reason" ]]; then
            log "Restart reason saved (will be injected by SessionStart hook): ${reason:0:80}..."
        fi
    fi

    # Run Claude Code
    log "Starting Claude Code (attempt after $crash_count crashes)"
    set +e
    if [[ ${#claude_args[@]} -gt 0 ]]; then
        claude "${claude_args[@]}"
    else
        claude
    fi
    exit_code=$?
    set -e

    log "Claude Code exited with code: $exit_code"

    case $exit_code in
        0)
            # Normal exit -- user or Claude decided to stop
            log "Clean exit (code 0). Stopping wrapper."
            echo 0 > "$CRASH_COUNT_FILE"
            break
            ;;
        129)
            # SIGHUP -- intentional self-restart
            log "Self-restart requested (code 129). Restarting..."
            echo 0 > "$CRASH_COUNT_FILE"
            sleep 0.5
            ;;
        2)
            # Hook blocked stop -- Claude should continue
            log "Stop blocked by hook (code 2). Restarting..."
            echo 0 > "$CRASH_COUNT_FILE"
            sleep 0.5
            ;;
        *)
            # Unexpected exit -- crash
            crash_count=$((crash_count + 1))
            echo "$crash_count" > "$CRASH_COUNT_FILE"
            log "Unexpected exit (code $exit_code). Crash count: $crash_count/$MAX_CRASHES"

            if [[ $crash_count -ge $MAX_CRASHES ]]; then
                log "Max crashes ($MAX_CRASHES) reached. Aborting."
                break
            fi

            # Exponential backoff: 2, 4, 8, 16, 32 seconds (bash 3.2 compatible)
            backoff=$INITIAL_BACKOFF
            i=1
            while [[ $i -lt $crash_count ]]; do
                backoff=$((backoff * 2))
                i=$((i + 1))
            done
            if [[ $backoff -gt 60 ]]; then
                backoff=60
            fi
            log "Backing off for ${backoff}s before retry..."
            sleep "$backoff"
            ;;
    esac
done

log "claude-self-reborn stopped."
