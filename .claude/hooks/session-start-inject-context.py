#!/usr/bin/env python3
"""SessionStart hook: Inject previous session context on restart.

When Claude Code starts (especially after a self-restart), this hook
reads the saved state and injects context so Claude knows why it restarted
and what it should do next.
"""

import json
import os
import sys
from pathlib import Path


def main() -> None:
    # Find project root
    cwd = Path.cwd()
    project_root = cwd
    for parent in [cwd, *cwd.parents]:
        if (parent / ".claude").is_dir():
            project_root = parent
            break

    state_dir = project_root / ".claude" / "self-reborn"
    if not state_dir.is_dir():
        return

    context_parts: list[str] = []

    # Check if this is a restart (restart_reason exists)
    restart_reason_file = state_dir / "restart_reason"
    if restart_reason_file.exists():
        reason = restart_reason_file.read_text().strip()
        if reason:
            context_parts.append(f"[Self-Reborn] Restarted. Reason: {reason}")
        # Consume the reason file so it's not re-injected on next start
        restart_reason_file.unlink()

    # Check for saved context
    context_file = state_dir / "context.md"
    if context_file.exists():
        context = context_file.read_text().strip()
        if context:
            context_parts.append(f"[Self-Reborn] Previous context:\n{context}")
        # Consume the context file
        context_file.unlink()

    # Check session history for restart count
    history_file = state_dir / "session_history.jsonl"
    if history_file.exists():
        lines = history_file.read_text().strip().split("\n")
        session_count = len(lines)
        if session_count > 1:
            context_parts.append(
                f"[Self-Reborn] Session #{session_count} (restarted {session_count - 1} times)"
            )

    if context_parts:
        # Output as additionalContext via JSON to stdout
        output = {"additionalContext": "\n".join(context_parts)}
        print(json.dumps(output))


if __name__ == "__main__":
    main()
