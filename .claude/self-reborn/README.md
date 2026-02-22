# Self-Reborn State Directory

Runtime state managed by the self-reborn system. All files here are gitignored.

## Files

| File | Purpose | Managed by |
|------|---------|------------|
| `session_id` | Current/last session ID for --resume | SessionEnd hook |
| `handoff.md` | Context to carry across restarts | Claude (before reload) |
| `session_history.jsonl` | Log of all sessions | SessionEnd hook |
