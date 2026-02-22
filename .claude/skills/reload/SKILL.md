# /reload -- Self-Restart Claude Code

tmux 内で動作中の Claude Code を停止し、同一セッションで再起動する。

## Trigger

User says: `/reload`, "reload", "restart", "reboot", "再起動"

## Prerequisites

- tmux 内で実行していること（tmux 外では動作しない）
- `scripts/reborn.sh` が存在すること

## Procedure

When this skill is invoked, execute the following steps in order:

### Step 1: Confirm tmux environment

```bash
echo "$TMUX_PANE"
```

If empty, tell the user: "tmux 内で実行してください。再起動にはtmuxが必要です。"
Abort.

### Step 2: Write handoff.md

Write `.claude/self-reborn/handoff.md` with:

```markdown
# Handoff

## Restart Reason
{why you are restarting}

## Current Task
{what you were working on}

## Next Steps
{what should be done after restart}

## Important Context
{decisions made, files changed, blockers, etc.}
```

Be specific. This is the only context your next self will receive.

### Step 3: Get session ID

```bash
echo "$CLAUDE_SESSION_ID"
```

If empty, check the saved file:
```bash
cat .claude/self-reborn/session_id 2>/dev/null
```

### Step 4: Launch restart script in new tmux window

```bash
tmux new-window -n reborn "./scripts/reborn.sh '$TMUX_PANE' '$SESSION_ID' '$(pwd)'"
```

After this command, the reborn script will:
1. Wait 2 seconds
2. Send Ctrl+C to your pane (stopping you)
3. Wait for you to exit
4. Run `claude --resume <session-id>` in your pane
5. Send the handoff prompt
6. Close itself

**You will be terminated after step 4.** This is expected.

## Arguments

| Argument | Action |
|----------|--------|
| (empty) | Interactive: ask for restart reason, then execute |
| `<reason>` | Use the given reason, execute immediately |

## Safety

- Only works inside tmux
- If reborn.sh fails, the original tmux pane remains (just at shell prompt)
- No wrapper loop -- one-shot restart
- Claude can be started normally again from the shell if anything goes wrong
