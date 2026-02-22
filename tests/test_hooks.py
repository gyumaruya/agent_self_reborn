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


def test_session_start_injects_restart_reason():
    """SessionStart hook injects restart reason as additionalContext."""
    with tempfile.TemporaryDirectory() as tmpdir:
        project = Path(tmpdir)
        state_dir = project / ".claude" / "self-reborn"
        state_dir.mkdir(parents=True)
        (state_dir / "restart_reason").write_text("Config updated, need fresh context")

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "session-start-inject-context.py")],
            cwd=str(project),
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0
        output = json.loads(result.stdout)
        assert "additionalContext" in output
        assert "Config updated, need fresh context" in output["additionalContext"]

        # Reason file should be consumed (deleted)
        assert not (state_dir / "restart_reason").exists()


def test_session_start_injects_context_file():
    """SessionStart hook injects saved context.md."""
    with tempfile.TemporaryDirectory() as tmpdir:
        project = Path(tmpdir)
        state_dir = project / ".claude" / "self-reborn"
        state_dir.mkdir(parents=True)
        (state_dir / "context.md").write_text("Working on feature X, step 3 of 5")

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "session-start-inject-context.py")],
            cwd=str(project),
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0
        output = json.loads(result.stdout)
        assert "Working on feature X, step 3 of 5" in output["additionalContext"]

        # Context file should be consumed
        assert not (state_dir / "context.md").exists()


def test_session_start_shows_session_count():
    """SessionStart hook shows restart count from history."""
    with tempfile.TemporaryDirectory() as tmpdir:
        project = Path(tmpdir)
        state_dir = project / ".claude" / "self-reborn"
        state_dir.mkdir(parents=True)

        # Simulate 3 previous sessions
        history = ""
        for i in range(3):
            entry = {"session_id": f"session-{i}", "event": "session_end"}
            history += json.dumps(entry) + "\n"
        (state_dir / "session_history.jsonl").write_text(history)

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "session-start-inject-context.py")],
            cwd=str(project),
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0
        output = json.loads(result.stdout)
        assert "Session #3" in output["additionalContext"]
        assert "restarted 2 times" in output["additionalContext"]


def test_session_start_no_state():
    """SessionStart hook outputs nothing when no state exists."""
    with tempfile.TemporaryDirectory() as tmpdir:
        project = Path(tmpdir)
        (project / ".claude").mkdir()

        result = subprocess.run(
            ["python3", str(HOOKS_DIR / "session-start-inject-context.py")],
            cwd=str(project),
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0
        assert result.stdout.strip() == ""


if __name__ == "__main__":
    test_session_end_saves_session_id()
    print("PASS: test_session_end_saves_session_id")

    test_session_end_no_session_id()
    print("PASS: test_session_end_no_session_id")

    test_session_start_injects_restart_reason()
    print("PASS: test_session_start_injects_restart_reason")

    test_session_start_injects_context_file()
    print("PASS: test_session_start_injects_context_file")

    test_session_start_shows_session_count()
    print("PASS: test_session_start_shows_session_count")

    test_session_start_no_state()
    print("PASS: test_session_start_no_state")

    print("\n=== All hook tests passed ===")
