# Research: Claude Code Self-Restart / Self-Terminate Mechanisms

Date: 2026-02-22
Researcher: Subagent (claude-sonnet-4-6)

---

## Executive Summary

Claude Code can terminate itself and be restarted via a wrapper script pattern. The key mechanism uses SIGHUP signal + exit code 129 detection. This is a proven, community-validated approach. tmux adds session persistence, making it ideal for self-improvement loops.

---

## 1. The /reload Command Pattern (KEY FINDING)

Source: https://www.panozzaj.com/blog/2026/02/07/building-a-reload-command-for-claude-code/

### Self-Termination Mechanism

Claude executes a bash command that sends SIGHUP to its own parent process:

```bash
kill -HUP $PPID
```

Exit code: **129** (128 + signal number 1, following Unix convention).

### Wrapper Script (Shell Function)

```bash
function CL {
  local continue_flag=""
  local restart_msg=""
  local rc
  while true; do
    claude --dangerously-skip-permissions $continue_flag "$@" $restart_msg
    rc=$?
    [ $rc -eq 129 ] || return $rc
    echo "Reloading Claude Code..."
    sleep 0.5
    continue_flag="-c"
    restart_msg="restarted"
  done
}
```

The wrapper loops continuously. When Claude exits with code 129:
1. It automatically restarts with `-c` flag (continue previous session)
2. Passes "restarted" message so Claude resumes without human intervention

### Skill Implementation (remarkably simple)

```markdown
# Reload Claude Code (restart Claude)

!`kill -HUP $PPID`
```

The `!` prefix executes instantly without LLM processing. Total restart time: ~1 second.

---

## 2. Claude Code Hooks System (Lifecycle Events)

Source: https://code.claude.com/docs/en/hooks

### Available Hook Events (as of Feb 2026)

| Event | When it fires | Blocking |
|-------|--------------|---------|
| `SessionStart` | Session begins or resumes | No |
| `UserPromptSubmit` | User submits a prompt | Yes |
| `PreToolUse` | Before tool call | Yes |
| `PermissionRequest` | Permission dialog | Yes |
| `PostToolUse` | After tool succeeds | No |
| `PostToolUseFailure` | After tool fails | No |
| `Notification` | When notification sent | No |
| `SubagentStart` | Subagent spawned | No |
| `SubagentStop` | Subagent finishes | Yes |
| **`Stop`** | **Claude finishes responding** | **Yes** |
| `TeammateIdle` | Teammate about to go idle | Yes |
| `TaskCompleted` | Task being marked complete | Yes |
| `ConfigChange` | Config file changes | Yes |
| `WorktreeCreate` | Worktree being created | Yes |
| `WorktreeRemove` | Worktree being removed | No |
| `PreCompact` | Before context compaction | No |
| **`SessionEnd`** | **Session terminates** | **No** |

### Key Hook for Self-Restart: Stop Hook

The `Stop` hook fires when Claude finishes responding. It can:
- **Block** Claude from stopping (exit code 2 or `{"decision": "block", "reason": "..."}`)
- Continue the conversation automatically

The `stop_hook_active` field prevents infinite loops:

```json
{
  "session_id": "abc123",
  "hook_event_name": "Stop",
  "stop_hook_active": true,
  "last_assistant_message": "I've completed the refactoring..."
}
```

### Stop Hook Usage for Self-Improvement Loop

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Evaluate if all tasks are complete: $ARGUMENTS. If not, block stopping with reason.",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### SessionEnd Hook

Fires when session terminates. Cannot block termination but can perform cleanup:

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/cleanup-and-restart.sh"
          }
        ]
      }
    ]
  }
}
```

Matcher values for SessionEnd: `clear`, `logout`, `prompt_input_exit`, `bypass_permissions_disabled`, `other`

---

## 3. Headless Mode / Programmatic Control

Source: https://code.claude.com/docs/en/headless

### Key CLI Flags

```bash
# Basic headless execution
claude -p "Your task here" --allowedTools "Bash,Read,Edit"

# JSON output with session ID
claude -p "Your task" --output-format json

# Stream output
claude -p "Your task" --output-format stream-json

# Continue previous session
claude -p "Continue" --continue

# Resume specific session
claude -p "Continue" --resume "$session_id"
```

### Session Chaining Pattern

```bash
# First request
session_id=$(claude -p "Start a review" --output-format json | jq -r '.session_id')

# Continue that specific session
claude -p "Continue that review" --resume "$session_id"
```

### Agent SDK (Python/TypeScript)

Anthropic released the Claude Agent SDK (formerly Claude Code SDK):
- Python: https://github.com/anthropics/claude-agent-sdk-python (v0.1.34 as of Feb 2026)
- TypeScript: https://github.com/anthropics/claude-agent-sdk-typescript (v0.2.37 as of Feb 2026)

Supports:
- Session resumption
- Tool approval callbacks
- Structured outputs
- Context compaction with `compact-2026-01-12` flag

---

## 4. tmux Integration Patterns

Sources:
- https://github.com/0xkaz/claunch
- https://github.com/nielsgroen/claude-tmux
- https://www.geeky-gadgets.com/making-claude-code-work-247-using-tmux/
- https://news.ycombinator.com/item?id=47104424 (Amux)

### Core tmux + Claude Code Pattern

```bash
# Start Claude in a detached tmux session
tmux new-session -d -s claude-session -c "$PROJECT_DIR" "claude --dangerously-skip-permissions"

# Attach to monitor
tmux attach -t claude-session

# Send a command to Claude running in tmux
tmux send-keys -t claude-session "your command" Enter

# Capture output
tmux capture-pane -t claude-session -p
```

### Amux (Multi-Agent Manager)

Tool for running 5-10 Claude Code agents simultaneously:
- Each agent runs in its own tmux pane
- Live status monitoring via SSE (working / needs input / idle)
- Web dashboard (PWA)
- REST API for scriptable orchestration
- Token usage tracking per agent

### claunch

Project-based Claude CLI session manager:
- Separates Claude sessions by project with tmux
- Automatically resumes existing session when run in same directory
- Uses `tmux has-session` to prevent duplicates

---

## 5. Self-Restart Architecture Patterns

### Pattern A: SIGHUP + Wrapper Script (Recommended)

```
Claude (running) --> executes kill -HUP $PPID --> exits with code 129
     |
     v
Wrapper script detects exit 129
     |
     v
Wrapper restarts: claude -c --dangerously-skip-permissions
     |
     v
Claude resumes with session history intact
```

**Pros**: Simple, proven, instant (~1 second), session continuity
**Cons**: Requires wrapper function in shell; `--dangerously-skip-permissions` needed

### Pattern B: tmux + watchdog process

```
tmux session "claude-main"
     |
     +-- Claude Code process
     |
tmux session "watchdog"
     |
     +-- Shell script monitoring Claude process
         if Claude exits: restart in tmux
```

```bash
#!/bin/bash
# watchdog.sh
while true; do
  if ! tmux has-session -t claude-session 2>/dev/null; then
    tmux new-session -d -s claude-session "claude -c --dangerously-skip-permissions"
    echo "Claude restarted at $(date)"
  fi
  sleep 5
done
```

**Pros**: Process isolation, can restart even on crash, good for 24/7 operation
**Cons**: More complex, polling-based (5-second gap)

### Pattern C: Stop Hook + Automated Re-prompting

```
Claude finishes task
     |
     v
Stop hook fires
     |
     +-- Evaluates if more work needed
     |
     +-- If yes: blocks stopping, provides next instruction
     |
     +-- If no: allows Claude to stop
```

**Pros**: No external process needed, native Claude mechanism
**Cons**: Claude never truly "restarts" (same session), can't address memory/context issues

### Pattern D: Headless Loop (for skill development)

```bash
#!/bin/bash
# self-improvement-loop.sh
TASK_FILE="$1"
MAX_ITERATIONS=10
ITERATION=0

session_id=$(claude -p "$(cat $TASK_FILE)" \
  --output-format json \
  --dangerously-skip-permissions | jq -r '.session_id')

while [ $ITERATION -lt $MAX_ITERATIONS ]; do
  RESULT=$(claude -p "Evaluate progress and continue or report done" \
    --resume "$session_id" \
    --output-format json \
    --dangerously-skip-permissions)

  STATUS=$(echo "$RESULT" | jq -r '.result' | grep -o "DONE\|CONTINUE")

  if [ "$STATUS" = "DONE" ]; then
    echo "Task complete after $ITERATION iterations"
    break
  fi

  ITERATION=$((ITERATION + 1))
done
```

**Pros**: External control, arbitrary loop logic, metrics collection
**Cons**: Each `-p` invocation is a new API call (cost); session continuation via `--resume` maintains context

---

## 6. Known Issues / Risks

### Self-Termination Risks

1. **Process Group Kill**: Claude Code and background processes share the same process group. Broad `pkill` commands can kill Claude itself (GitHub issue #9970, #3068, #10803)
2. **Parent Process Kill**: If Claude kills VS Code / the terminal, the session is lost
3. **Docker Containers**: Background process termination crashes Claude in containers (issue #16135)

### Mitigation

- Use `kill -HUP $PPID` specifically (targets parent only)
- Use exit code 129 as the restart signal (not crash)
- Always run inside tmux (if Claude's process dies, tmux session survives)
- Use `--dangerously-skip-permissions` for unattended operation

### Rate Limiting

- Usage limits can interrupt long-running loops
- `claude-auto-resume` (https://github.com/terryso/claude-auto-resume) handles this by detecting limit messages and waiting for reset timestamp

---

## 7. Recommended Architecture for Self-Improvement Loop

```
┌─────────────────────────────────────────┐
│  tmux session "orchestrator"            │
│                                         │
│  loop_manager.sh (bash)                 │
│    - Maintains state file               │
│    - Tracks iteration count             │
│    - Handles rate limit recovery        │
│                                         │
│  function CL {                          │
│    while true; do                       │
│      claude -c --dangerously-skip-permissions │
│      if exit 129: restart              │
│      else: break                        │
│    done                                 │
│  }                                      │
└─────────────────────────────────────────┘
         |
         | spawns / monitors
         v
┌─────────────────────────────────────────┐
│  tmux session "claude-worker"           │
│                                         │
│  Claude Code process                    │
│    - Has /reload skill (kill -HUP $PPID)│
│    - Stop hook evaluates completion     │
│    - SessionEnd hook logs state         │
│                                         │
│  Can self-terminate via:                │
│    kill -HUP $PPID  → exit 129          │
│    OR: natural completion               │
└─────────────────────────────────────────┘
```

### Implementation Steps

1. Create shell wrapper function `CL` that catches exit 129
2. Create `/reload` skill: `!kill -HUP $PPID`
3. Configure `SessionEnd` hook to save state to file
4. Configure `Stop` hook to evaluate task completion
5. Wrap everything in tmux for session persistence
6. Add rate-limit detection (check for usage limit messages)

---

## 8. Existing Tools / Projects

| Tool | URL | Mechanism |
|------|-----|-----------|
| claunch | https://github.com/0xkaz/claunch | tmux session manager |
| claude-tmux | https://github.com/nielsgroen/claude-tmux | tmux popup + session management |
| Amux | HN: 47104424 | Multi-agent tmux orchestration |
| claude-auto-resume | https://github.com/terryso/claude-auto-resume | Rate limit recovery |
| claude-flow | https://github.com/ruvnet/claude-flow | Full session persistence framework |
| /reload skill | https://www.panozzaj.com/blog/2026/02/07/building-a-reload-command-for-claude-code/ | SIGHUP self-restart |

---

## Sources

- https://www.panozzaj.com/blog/2026/02/07/building-a-reload-command-for-claude-code/
- https://code.claude.com/docs/en/hooks
- https://code.claude.com/docs/en/headless
- https://github.com/terryso/claude-auto-resume
- https://github.com/0xkaz/claunch
- https://github.com/nielsgroen/claude-tmux
- https://github.com/anthropics/claude-code/issues/9970
- https://github.com/anthropics/claude-code/issues/10803
- https://github.com/ruvnet/claude-flow/wiki/session-persistence
- https://news.ycombinator.com/item?id=47104424
- https://adim.in/p/remote-control-claude-code/
- https://platform.claude.com/docs/en/agent-sdk/overview
