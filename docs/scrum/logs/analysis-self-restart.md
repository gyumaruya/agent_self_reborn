# Technical Analysis: Claude Code Self-Restart Mechanism

Date: 2026-02-22
Analyst: Subagent (Codex consultation)

---

## Executive Summary

Claude Code supports session persistence natively via `--resume <session-id>` and `--continue` flags. The most feasible self-restart architecture combines a **wrapper supervisor script** with **session ID preservation**. tmux provides optional UX enhancement but is not required.

---

## Claude Code Process Lifecycle

### Key Facts

- **Runtime**: Node.js process
- **Session storage**: `~/.claude/projects/<dir-path>/<session-id>.jsonl`
- **Session ID format**: UUID v4 (e.g., `0021f0c5-d0bd-423c-b5d5-87f0deefafd4`)
- **Environment variable**: `CLAUDE_SESSION_ID` exposed to hooks
- **Version tested**: 2.1.50

### Session File Location

```
~/.claude/projects/-Users-{username}-{project-name}/
├── <session-id>           # Session metadata directory
└── <session-id>.jsonl     # Full conversation history (JSONL format)
```

### JSONL Record Format

Each line in the session file contains:
```json
{
  "parentUuid": "...",
  "isSidechain": false,
  "userType": "external",
  "cwd": "/path/to/project",
  "sessionId": "<uuid>",
  "version": "2.1.50",
  "type": "system|human|assistant",
  "content": "...",
  "timestamp": "2026-02-22T08:41:48.580Z",
  "uuid": "<message-uuid>"
}
```

---

## CLI Flags for State Continuity

| Flag | Description | Use Case |
|------|-------------|----------|
| `--continue` / `-c` | Resume most recent conversation in CWD | Simple restart fallback |
| `--resume <id>` / `-r` | Resume by exact session ID | Precise session restoration |
| `--session-id <uuid>` | Start with a specific session ID | Pre-assign session ID |
| `--fork-session` | Create new session ID when resuming | Branch from previous session |
| `--no-session-persistence` | Disable session saving | Non-interactive/ephemeral use |

### Recommendation

Use `--resume <session-id>` over `--continue` for:
- Precision (not ambiguous about "most recent")
- Works even when multiple projects have recent sessions
- Can be combined with `--fork-session` for clean restarts with inherited context

---

## Approach Evaluation

### A) tmux + Wrapper Script

**Feasibility**: High (tmux 3.6a available at `/opt/homebrew/bin/tmux`)

**Pros**:
- Easy terminal reattachment with `tmux attach -t <session>`
- Process isolation
- Can run headless as background service

**Cons**:
- `--tmux` flag requires `--worktree` (limited to worktree workflow)
- Additional complexity for session naming

**State preservation**: Good via `claude --continue` or `--resume`

**Rating**: Recommended as optional UX enhancement

---

### B) Claude Code Hooks

**Feasibility**: Medium (hooks exist but limited trigger points)

**Available Hook Events** (from reference implementation):
- `SessionEnd` - fires when session terminates
- Environment variable `CLAUDE_SESSION_ID` available in hooks

**Hook Output Format**:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionEnd",
    "additionalContext": "..."
  }
}
```

**Pros**:
- Native integration
- Access to session ID via `CLAUDE_SESSION_ID`
- Can save session state cleanly

**Cons**:
- Cannot directly restart Claude Code from within Claude Code
- Only useful for saving state, not triggering restart
- Hook must exit before Claude terminates

**Best use**: Save session ID to file for external wrapper to use

**Rating**: Complementary tool, not standalone solution

---

### C) Process Supervisor (systemd/launchd)

**Feasibility**: High (macOS launchd available)

**Pros**:
- Battle-tested reliability
- Automatic restart on crash
- Logging built-in
- Start on login

**Cons**:
- macOS launchd plist complexity
- Interactive TTY requirements may complicate things
- Needs `--print` mode or pseudo-TTY for non-interactive use

**Rating**: Best for always-on daemon mode, overkill for interactive use

---

### D) Self-Exec Wrapper Script (RECOMMENDED)

**Feasibility**: High (simple bash)

**Pros**:
- Simplest implementation
- Works with any exit code
- Portable (just bash + claude)
- Easy to customize backoff/retry logic

**Cons**:
- No built-in TTY management
- Must handle stdin/stdout carefully for interactive mode

**Rating**: Best default approach for interactive sessions

---

### E) Session ID Preservation (COMPLEMENTS D)

**Mechanism**:
1. Read session ID from `~/.claude/projects/<dir>/*.jsonl` (most recent file)
2. Or use `SessionEnd` hook to write ID to file
3. Wrapper reads ID on restart, passes to `--resume <id>`

**Rating**: Required component for precise state restoration

---

## Recommended MVP Architecture

### Architecture: Wrapper Script + Session ID File

```
┌─────────────────────────────────────────┐
│  claude-restart.sh (Wrapper/Supervisor) │
│                                         │
│  1. Check $SESSION_FILE for saved ID    │
│  2. Build: claude --resume <id>         │
│     OR: claude --continue (fallback)    │
│  3. Run claude, capture output          │
│  4. On exit: find latest session ID     │
│  5. Save to $SESSION_FILE               │
│  6. Sleep + restart loop                │
└─────────────────────────────────────────┘
         │ runs
         ▼
┌─────────────────────────────────────────┐
│  Claude Code (Interactive Session)      │
│  ~/.claude/projects/<proj>/<id>.jsonl   │
│  SessionEnd hook → writes session ID    │
└─────────────────────────────────────────┘
```

### Concrete Implementation

```bash
#!/usr/bin/env bash
# claude-restart.sh - Self-restarting Claude Code wrapper
set -euo pipefail

# Configuration
PROJECT_DIR="${1:-$(pwd)}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-restart"
SESSION_FILE="$STATE_DIR/session_id"
LOG_FILE="$STATE_DIR/claude.log"
BACKOFF_SECONDS=2
MAX_RESTARTS=0  # 0 = infinite

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

# Find latest session ID from Claude's project storage
find_latest_session_id() {
    local project_key
    project_key=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
    local sessions_dir="$HOME/.claude/projects/${project_key}"

    if [[ -d "$sessions_dir" ]]; then
        # Find most recently modified .jsonl file
        local latest
        latest=$(ls -t "$sessions_dir"/*.jsonl 2>/dev/null | head -1)
        if [[ -n "$latest" ]]; then
            # Extract session ID from filename
            basename "$latest" .jsonl
        fi
    fi
}

# Save current session ID
save_session_id() {
    local sid
    sid=$(find_latest_session_id)
    if [[ -n "$sid" ]]; then
        echo "$sid" > "$SESSION_FILE"
        chmod 600 "$SESSION_FILE"
        echo "[restart] Session ID saved: $sid" >&2
    fi
}

# Build claude command
build_cmd() {
    local args=()

    if [[ -s "$SESSION_FILE" ]]; then
        local sid
        sid="$(<"$SESSION_FILE")"
        args+=("--resume" "$sid")
        echo "[restart] Resuming session: $sid" >&2
    else
        args+=("--continue")
        echo "[restart] Starting fresh with --continue" >&2
    fi

    echo "claude" "${args[@]}"
}

# Main supervisor loop
restart_count=0
while true; do
    if [[ $MAX_RESTARTS -gt 0 && $restart_count -ge $MAX_RESTARTS ]]; then
        echo "[restart] Max restarts ($MAX_RESTARTS) reached. Exiting." >&2
        exit 1
    fi

    cmd=$(build_cmd)
    echo "[restart] Starting: $cmd" >&2
    echo "$(date -Iseconds) Starting restart #$restart_count" >> "$LOG_FILE"

    # Run Claude Code
    if $cmd; then
        exit_code=0
    else
        exit_code=$?
    fi

    echo "[restart] Claude exited with code $exit_code" >&2
    echo "$(date -Iseconds) Exited with code $exit_code" >> "$LOG_FILE"

    # Save session ID after exit
    save_session_id

    # Optional: exit on clean exit (code 0) to allow intentional stops
    if [[ $exit_code -eq 0 ]]; then
        echo "[restart] Clean exit. Restarting in ${BACKOFF_SECONDS}s..." >&2
    fi

    ((restart_count++))
    sleep "$BACKOFF_SECONDS"
done
```

### Session ID Hook (Optional Enhancement)

Create `.claude/hooks/session-end-save-id.py`:

```python
#!/usr/bin/env python3
"""Hook: Save session ID on session end for self-restart mechanism."""
import json
import os
import sys
from pathlib import Path

def main():
    try:
        json.load(sys.stdin)
    except Exception:
        pass

    session_id = os.environ.get("CLAUDE_SESSION_ID", "")
    if session_id:
        state_dir = Path.home() / ".local" / "state" / "claude-restart"
        state_dir.mkdir(parents=True, exist_ok=True)

        session_file = state_dir / "session_id"
        session_file.write_text(session_id)
        session_file.chmod(0o600)
        print(f"[session-end-save-id] Session ID saved: {session_id}", file=sys.stderr)

    json.dump({"continue": True}, sys.stdout)
    sys.exit(0)

if __name__ == "__main__":
    main()
```

### Optional: tmux Wrapper

```bash
#!/usr/bin/env bash
# Start wrapper in tmux for easy reattachment
SESSION_NAME="claude-restart"

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux attach-session -t "$SESSION_NAME"
else
    tmux new-session -d -s "$SESSION_NAME" "/path/to/claude-restart.sh $(pwd)"
    tmux attach-session -t "$SESSION_NAME"
fi
```

---

## Security Considerations

1. **Session ID confidentiality**: Store in `chmod 600` file - session IDs grant conversation access
2. **State directory permissions**: `chmod 700` on state directory
3. **Log sanitization**: Avoid logging conversation content; log only metadata
4. **Restart limits**: Implement `MAX_RESTARTS` to prevent infinite loops on hard failures
5. **tmux shared sessions**: Avoid shared tmux sockets in multi-user environments

---

## Implementation Steps (MVP)

1. **Create wrapper script** at `~/.local/bin/claude-restart`
2. **Make executable**: `chmod +x ~/.local/bin/claude-restart`
3. **Test basic restart**: Run `claude-restart .` and verify `--continue` works
4. **Add session ID capture**: Implement `find_latest_session_id()` function
5. **Test session resume**: Kill claude mid-session, verify restart picks up from `--resume <id>`
6. **Optional: Add hook**: Configure `SessionEnd` hook to pre-save session ID
7. **Optional: Add tmux**: Wrap in tmux for reattachment capability

---

## References

- Claude Code CLI: `claude --help`
- Session storage: `~/.claude/projects/<project>/`
- Hook example: `~/projects/resources/hooks/session-end.py`
- tmux version: 3.6a at `/opt/homebrew/bin/tmux`
