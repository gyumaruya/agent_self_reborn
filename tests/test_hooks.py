"""Tests for self-reborn hooks."""

import json
import os
import subprocess
import tempfile
from pathlib import Path

HOOKS_DIR = Path(__file__).parent.parent / ".claude" / "hooks"


def test_session_end_saves_session_id():
    """SessionEnd hook saves session ID to state file."""
    with tempfile.TemporaryDirectory() as tmpdir:
        project = Path(tmpdir)
        (project / ".claude").mkdir()

        env = os.environ.copy()
        env["CLAUDE_SESSION_ID"] = "test-session-12345"

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "session-end-save-state.py")],
            cwd=str(project),
            env=env,
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0

        state_dir = project / ".claude" / "self-reborn"
        assert (state_dir / "session_id").exists()
        assert (state_dir / "session_id").read_text() == "test-session-12345"

        # Check history
        assert (state_dir / "session_history.jsonl").exists()
        history = (state_dir / "session_history.jsonl").read_text().strip()
        entry = json.loads(history)
        assert entry["session_id"] == "test-session-12345"
        assert entry["event"] == "session_end"


def test_session_end_no_session_id():
    """SessionEnd hook does nothing without session ID."""
    with tempfile.TemporaryDirectory() as tmpdir:
        project = Path(tmpdir)
        (project / ".claude").mkdir()

        env = os.environ.copy()
        env.pop("CLAUDE_SESSION_ID", None)

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "session-end-save-state.py")],
            cwd=str(project),
            env=env,
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0
        assert not (project / ".claude" / "self-reborn").exists()


def test_session_end_appends_history():
    """SessionEnd hook appends to existing history."""
    with tempfile.TemporaryDirectory() as tmpdir:
        project = Path(tmpdir)
        state_dir = project / ".claude" / "self-reborn"
        state_dir.mkdir(parents=True)

        # Pre-existing history
        existing = json.dumps({"session_id": "old-session", "event": "session_end"})
        (state_dir / "session_history.jsonl").write_text(existing + "\n")

        env = os.environ.copy()
        env["CLAUDE_SESSION_ID"] = "new-session"

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "session-end-save-state.py")],
            cwd=str(project),
            env=env,
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0

        lines = (state_dir / "session_history.jsonl").read_text().strip().split("\n")
        assert len(lines) == 2
        assert json.loads(lines[0])["session_id"] == "old-session"
        assert json.loads(lines[1])["session_id"] == "new-session"


if __name__ == "__main__":
    test_session_end_saves_session_id()
    print("PASS: test_session_end_saves_session_id")

    test_session_end_no_session_id()
    print("PASS: test_session_end_no_session_id")

    test_session_end_appends_history()
    print("PASS: test_session_end_appends_history")

    print("\n=== All hook tests passed ===")
