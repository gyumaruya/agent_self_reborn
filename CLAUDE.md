# claude_self_reborn

Claude Code が自身を停止・再起動できるセルフリスタート機構。
スキル開発や自己改善ループの基盤。

詳細なドキュメントは `README.md` を参照。

## Self-Reborn System

### How it Works

1. `claude-self-reborn.sh` が Claude Code をラップして実行
2. Claude が `kill -HUP $PPID` を実行すると exit code 129 で終了
3. ラッパーが 129 を検出し、`--resume` で同一セッションを再起動
4. `SessionEnd` hook がセッションIDを保存、`SessionStart` hook が前回の状態を注入

### Self-Restart の方法

再起動したい場合は以下を実行:

```bash
# 1. 理由を書く（任意）
echo "理由" > .claude/self-reborn/restart_reason

# 2. コンテキストを書く（任意）
echo "引き継ぎ内容" > .claude/self-reborn/context.md

# 3. 再起動シグナル
kill -HUP $PPID
```

### Key Files

| File | Purpose |
|------|---------|
| `scripts/claude-self-reborn.sh` | 再起動ラッパー（exit 129 検出ループ） |
| `scripts/start-tmux.sh` | tmux セッション起動 |
| `.claude/skills/reload/SKILL.md` | /reload スキル定義 |
| `.claude/hooks/session-end-save-state.py` | 終了時: セッションID保存 |
| `.claude/hooks/session-start-inject-context.py` | 起動時: 前回状態注入 |
| `.claude/self-reborn/` | ランタイム状態（gitignore対象） |

### Safety

- 連続クラッシュ5回でラッパー停止
- 指数バックオフ（2s, 4s, 8s, 16s, 32s, max 60s）
- exit 0 でラッパー完全停止（無限ループなし）

## Scrum

This project uses Scrum for development management.

### Scrum Environment

- **Backlog**: `docs/scrum/backlog.md`
- **Sprint tracking**: `docs/scrum/sprints/current.md`
- **Code review**: Pull Requests (via `gh` CLI)
- **Sprint archive**: `docs/scrum/sprints/YYYY-MM-DD_sprint-NNN/`

### Automatic Ceremony Flow

1. Stakeholder desire -> PO creates backlog items -> Planning auto-starts -> Dev implements
2. Increment ready -> Review auto-runs -> stakeholder gives feedback
3. Review done -> Retro auto-runs -> SM improves organization -> archive sprint

### Scrum Agents

| Agent | File | Role |
|-------|------|------|
| Product Owner | `.claude/agents/scrum-product-owner.md` | Backlog management, prioritization |
| Scrum Master | `.claude/agents/scrum-master.md` | Process improvement, retrospectives |
| Developer | `.claude/agents/scrum-developer.md` | Implementation, testing |
