# Reload Claude Code

Restart the current Claude Code session. The wrapper script will detect
exit code 129 and restart with --resume to continue the session.

## Usage

User says: /reload, "reload", "restart", "reboot"

## Arguments

| Argument | Action |
|----------|--------|
| (empty) | Reload immediately |
| `<reason>` | Save reason to state file, then reload |

## How it works

1. Save restart reason to `.claude/self-reborn/restart_reason` (if provided)
2. Save current session context to `.claude/self-reborn/context.md`
3. Send SIGHUP to parent process: `kill -HUP $PPID`
4. Wrapper detects exit 129 and restarts with `--resume`

## Implementation

When this skill is invoked:

1. If arguments are provided, write them to `.claude/self-reborn/restart_reason`:
```bash
echo "{reason}" > .claude/self-reborn/restart_reason
```

2. Send the reload signal:
```bash
kill -HUP $PPID
```

That's it. The wrapper script handles the rest.

## Safety

- Only works inside the `claude-self-reborn.sh` wrapper
- Without the wrapper, SIGHUP just terminates the session (no restart)
- Crash counter prevents infinite restart loops
