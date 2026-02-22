#!/usr/bin/env python3
"""SessionEnd hook: Save session ID and state for restart continuity.

When Claude Code exits, this hook saves the current session ID
so the wrapper script can resume the exact same session.
"""

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


def main() -> None:
    session_id = os.environ.get("CLAUDE_SESSION_ID", "")
    if not session_id:
        return

    # Find project root (walk up from CWD looking for .claude/)
    cwd = Path.cwd()
    project_root = cwd
    for parent in [cwd, *cwd.parents]:
        if (parent / ".claude").is_dir():
            project_root = parent
            break

    state_dir = project_root / ".claude" / "self-reborn"
    state_dir.mkdir(parents=True, exist_ok=True)

    # Save session ID
    (state_dir / "session_id").write_text(session_id)

    # Append to session history
    history_file = state_dir / "session_history.jsonl"
    entry = {
        "timestamp": datetime.now(tz=timezone.utc).isoformat(),
        "session_id": session_id,
        "event": "session_end",
    }
    with history_file.open("a") as f:
        f.write(json.dumps(entry) + "\n")


if __name__ == "__main__":
    main()
