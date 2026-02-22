# Self-Reborn State Directory

This directory is managed by the claude-self-reborn system.
Do not edit these files manually unless debugging.

## Files

| File | Purpose | Managed by |
|------|---------|------------|
| `session_id` | Current/last session ID for --resume | SessionEnd hook |
| `restart_reason` | Why Claude requested restart (consumed on start) | /reload skill |
| `context.md` | Freeform context to carry across restarts | Claude (before reload) |
| `session_history.jsonl` | Log of all sessions | SessionEnd hook |
| `crash_count` | Consecutive crash counter | Wrapper script |
| `restart.log` | Human-readable restart log | Wrapper script |
