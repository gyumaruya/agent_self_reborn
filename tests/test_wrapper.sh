#!/bin/bash
# test_reborn.sh -- Tests for reborn.sh restart executor
#
# Tests argument validation and script structure.
# Full integration test requires tmux (skipped in CI).

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REBORN="$PROJECT_DIR/scripts/reborn.sh"

echo "=== Test: reborn.sh ==="
echo ""

# --- Test 1: Syntax check ---
echo "--- Test 1: Bash syntax valid ---"
bash -n "$REBORN" && echo "  PASS: Syntax OK" || { echo "  FAIL: Syntax error"; exit 1; }

# --- Test 2: Missing arguments exits with error ---
echo "--- Test 2: Missing arguments shows usage ---"
output=$(bash "$REBORN" 2>&1 || true)
if echo "$output" | grep -q "Usage:"; then
    echo "  PASS: Shows usage on missing args"
else
    echo "  FAIL: Did not show usage"
    echo "  Output: $output"
    exit 1
fi

# --- Test 3: Partial arguments exits with error ---
echo "--- Test 3: Partial arguments shows usage ---"
output=$(bash "$REBORN" "%0" 2>&1 || true)
if echo "$output" | grep -q "Usage:"; then
    echo "  PASS: Shows usage on partial args"
else
    echo "  FAIL: Did not show usage"
    exit 1
fi

# --- Test 4: Script is executable ---
echo "--- Test 4: Script has execute permission ---"
if [[ -x "$REBORN" ]]; then
    echo "  PASS: Executable"
else
    echo "  FAIL: Not executable"
    exit 1
fi

# --- Test 5: tmux integration (skip if no tmux or not in tmux) ---
echo "--- Test 5: tmux integration (requires tmux session) ---"
if [[ -z "$TMUX" ]]; then
    echo "  SKIP: Not running inside tmux"
else
    # Verify tmux commands used in reborn.sh exist
    if tmux display-message -p '#{pane_current_command}' >/dev/null 2>&1; then
        echo "  PASS: tmux display-message works"
    else
        echo "  FAIL: tmux display-message failed"
        exit 1
    fi
fi

echo ""
echo "=== All tests passed ==="
