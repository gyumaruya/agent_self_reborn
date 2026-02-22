#!/bin/bash
# test_wrapper.sh -- Integration test for claude-self-reborn.sh
#
# Creates a mock 'claude' command and verifies wrapper behavior:
# 1. Exit 129 triggers restart
# 2. Exit 0 stops the loop
# 3. Crash counter and backoff work
# 4. Session ID is passed via --resume

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_DIR=$(mktemp -d)
MOCK_BIN="$TEST_DIR/bin"

mkdir -p "$MOCK_BIN"

# Cleanup on exit
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Common env for all tests (fast: no backoff)
export CLAUDE_SELF_REBORN_STATE_DIR=".claude/self-reborn"
export CLAUDE_SELF_REBORN_BACKOFF=0
export CLAUDE_SELF_REBORN_MAX_CRASHES=5

echo "=== Test: claude-self-reborn.sh ==="
echo ""

# Helper: create mock claude that exits with given codes in sequence
# Usage: create_mock <code1> <code2> ... <codeN>
# Calls beyond N always exit 0
create_mock() {
    local count_file="$TEST_DIR/call_count"
    local args_log="$TEST_DIR/args_log"
    echo 0 > "$count_file"
    : > "$args_log"

    local codes=("$@")
    local mock_script="$MOCK_BIN/claude"

    cat > "$mock_script" << ENDMOCK
#!/bin/bash
count=\$(cat "$count_file")
count=\$((count + 1))
echo \$count > "$count_file"
echo "\$@" >> "$args_log"
ENDMOCK

    # Write the exit code logic
    local i=0
    for code in "${codes[@]}"; do
        i=$((i + 1))
        echo "if [[ \$count -eq $i ]]; then exit $code; fi" >> "$mock_script"
    done
    echo "exit 0" >> "$mock_script"

    chmod +x "$mock_script"
}

get_call_count() {
    cat "$TEST_DIR/call_count"
}

get_args_log() {
    cat "$TEST_DIR/args_log" 2>/dev/null
}

# --- Test 1: Exit 129 triggers restart, then exit 0 stops ---
echo "--- Test 1: Restart on 129, stop on 0 ---"

create_mock 129 129 0
mkdir -p "$TEST_DIR/project1/.claude"

PATH="$MOCK_BIN:$PATH" \
    bash "$PROJECT_DIR/scripts/claude-self-reborn.sh" "$TEST_DIR/project1" > "$TEST_DIR/output_1.log" 2>&1

count=$(get_call_count)
if [[ $count -eq 3 ]]; then
    echo "  PASS: Claude called 3 times (2 restarts + 1 clean exit)"
else
    echo "  FAIL: Expected 3 calls, got $count"
    cat "$TEST_DIR/output_1.log"
    exit 1
fi

# --- Test 2: Session ID passed via --resume ---
echo "--- Test 2: Session ID passed via --resume ---"

create_mock 0
mkdir -p "$TEST_DIR/project2/.claude/self-reborn"
echo "test-session-abc-123" > "$TEST_DIR/project2/.claude/self-reborn/session_id"

PATH="$MOCK_BIN:$PATH" \
    bash "$PROJECT_DIR/scripts/claude-self-reborn.sh" "$TEST_DIR/project2" > "$TEST_DIR/output_2.log" 2>&1

if echo "$(get_args_log)" | grep -q "test-session-abc-123"; then
    echo "  PASS: Session ID passed to claude --resume"
else
    echo "  FAIL: Session ID not found in args"
    echo "  Args: $(get_args_log)"
    cat "$TEST_DIR/output_2.log"
    exit 1
fi

# --- Test 3: Crash counter stops after MAX_CRASHES ---
echo "--- Test 3: Crash counter stops at max ---"

create_mock 1 1 1 1 1 1 1
mkdir -p "$TEST_DIR/project3/.claude"

PATH="$MOCK_BIN:$PATH" \
CLAUDE_SELF_REBORN_MAX_CRASHES=3 \
    bash "$PROJECT_DIR/scripts/claude-self-reborn.sh" "$TEST_DIR/project3" > "$TEST_DIR/output_3.log" 2>&1

count=$(get_call_count)
if [[ $count -eq 3 ]]; then
    echo "  PASS: Stopped after 3 crashes"
else
    echo "  FAIL: Expected 3 crash attempts, got $count"
    cat "$TEST_DIR/output_3.log"
    exit 1
fi

# --- Test 4: Exit 0 stops wrapper (no loop) ---
echo "--- Test 4: Clean exit stops wrapper ---"

create_mock 0
mkdir -p "$TEST_DIR/project4/.claude"

PATH="$MOCK_BIN:$PATH" \
    bash "$PROJECT_DIR/scripts/claude-self-reborn.sh" "$TEST_DIR/project4" > "$TEST_DIR/output_4.log" 2>&1

count=$(get_call_count)
if [[ $count -eq 1 ]]; then
    echo "  PASS: Single run, clean exit"
else
    echo "  FAIL: Expected 1 call, got $count"
    cat "$TEST_DIR/output_4.log"
    exit 1
fi

echo ""
echo "=== All tests passed ==="
