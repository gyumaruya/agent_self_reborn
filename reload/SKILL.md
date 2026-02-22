---
name: reload
description: >
  Restart the current Claude Code session from within tmux.
  Writes a handoff file, launches a restart script in a new tmux window,
  which stops the current Claude and resumes with --resume.
  Triggers: /reload, "reload", "restart", "reboot", "再起動"
---

# /reload -- Self-Restart Claude Code

tmux 内で動作中の Claude Code を停止し、同一セッションで再起動する。
handoff.md に引き継ぎ情報を書き、別の tmux ウィンドウから元のペインを操作する。

## When to use

- コンテキストが重くなった時
- スキルや設定を変更して再読み込みしたい時
- フェーズを切り替えたい時（調査 → 実装 など）
- Claude 自身が再起動すべきと判断した時

## Prerequisites

- tmux 内で実行していること（tmux 外では動作しない）

## Instructions

### Step 1: tmux 環境を確認

```bash
echo "TMUX_PANE=$TMUX_PANE"
```

`TMUX_PANE` が空なら、ユーザーに「tmux 内で実行してください」と伝えて中止。

### Step 2: handoff.md を書く

`.claude/self-reborn/handoff.md` に引き継ぎ情報を書く。
これが再起動後の自分が受け取る唯一のコンテキスト。具体的に書くこと。

```bash
mkdir -p .claude/self-reborn
cat > .claude/self-reborn/handoff.md << 'HANDOFF_EOF'
# Handoff

## Restart Reason
{なぜ再起動するか -- 具体的に}

## Current Task
{何をしていたか -- ファイル名、行番号、進捗}

## Next Steps
{次に何をすべきか -- 具体的なアクション}

## Important Context
{引き継ぎたい情報 -- 決定事項、注意点、ブロッカー}
HANDOFF_EOF
```

### Step 3: セッション ID を取得

```bash
SESSION_ID=$(cat .claude/self-reborn/session_id 2>/dev/null || echo "")
echo "SESSION_ID=$SESSION_ID"
```

SESSION_ID が空の場合も `--continue` で代用できるので続行可能。

### Step 4: 再起動スクリプトを生成して実行

以下のコマンドで一時スクリプトを作成し、別の tmux ウィンドウで実行する。

```bash
REBORN_SCRIPT=$(mktemp /tmp/claude-reborn-XXXXXX.sh)
PANE="$TMUX_PANE"
PROJECT="$(pwd)"
# SESSION_ID は Step 3 で取得済み

cat > "$REBORN_SCRIPT" << REBORN_EOF
#!/bin/bash
set -eo pipefail

TARGET_PANE="$PANE"
SESSION_ID="$SESSION_ID"
PROJECT_DIR="$PROJECT"
HANDOFF="\$PROJECT_DIR/.claude/self-reborn/handoff.md"

log() { echo "[reborn] \$(date '+%H:%M:%S') \$1"; }

log "Waiting 2s before stopping Claude..."
sleep 2

log "Sending Ctrl+C to \$TARGET_PANE"
tmux send-keys -t "\$TARGET_PANE" C-c

# Wait for Claude to exit (poll pane_current_command)
log "Waiting for Claude to exit..."
for i in \$(seq 1 30); do
    sleep 1
    fg=\$(tmux display-message -t "\$TARGET_PANE" -p '#{pane_current_command}' 2>/dev/null || echo "")
    case "\$fg" in bash|zsh|sh|fish) log "Claude exited (\${i}s)"; break;; esac
    if [ "\$i" -eq 5 ] || [ "\$i" -eq 15 ]; then
        log "Still running (\$fg), retrying Ctrl+C..."
        tmux send-keys -t "\$TARGET_PANE" C-c
    fi
done

# Resume Claude
log "Restarting Claude..."
sleep 1
if [ -n "\$SESSION_ID" ]; then
    tmux send-keys -t "\$TARGET_PANE" "cd '\$PROJECT_DIR' && claude --resume '\$SESSION_ID'" Enter
else
    tmux send-keys -t "\$TARGET_PANE" "cd '\$PROJECT_DIR' && claude --continue" Enter
fi

# Send handoff prompt after Claude starts
log "Waiting 8s for Claude to start..."
sleep 8
if [ -f "\$HANDOFF" ]; then
    tmux send-keys -t "\$TARGET_PANE" ".claude/self-reborn/handoff.md を読んで、再起動理由と次のステップを確認して作業を続けてください。" Enter
    log "Handoff prompt sent"
fi

log "Done. Closing in 3s..."
sleep 3
rm -f "\$0"
REBORN_EOF

chmod +x "$REBORN_SCRIPT"
tmux new-window -n reborn "$REBORN_SCRIPT"
```

**このコマンドの実行後、2秒以内に Ctrl+C が送られて自分は停止する。これは正常動作。**

## Arguments

| Argument | Action |
|----------|--------|
| (empty) | 再起動理由を聞いてから実行 |
| `<reason>` | 指定された理由で即座に実行 |

## Safety

- tmux 外では動作しない（Step 1 で検出）
- 一時スクリプトは実行後に自己削除
- 失敗しても元のペインのシェルは残る（手動で `claude` を再起動可能）
- ラッパーループなし -- 一発実行のみ
