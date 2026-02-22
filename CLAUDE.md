# claude_self_reborn

Claude Code が自身を停止・再起動できる仕組み。詳細は `README.md` を参照。

## Self-Reborn: 使い方

### 前提

- tmux 内で実行していること

### 再起動の手順

```bash
# 1. handoff.md に引き継ぎ情報を書く
mkdir -p .claude/self-reborn
cat > .claude/self-reborn/handoff.md << 'EOF'
# Handoff
## Restart Reason
{なぜ再起動するか}
## Current Task
{何をしていたか}
## Next Steps
{次に何をすべきか}
## Important Context
{引き継ぎたい情報}
EOF

# 2. セッションIDを取得
SESSION_ID=$(cat .claude/self-reborn/session_id)

# 3. 別ウィンドウで reborn.sh を起動
tmux new-window -n reborn "./scripts/reborn.sh '$TMUX_PANE' '$SESSION_ID' '$(pwd)'"
```

reborn.sh が Claude を停止 → 再起動 → handoff.md 読み込み指示を送る。

### Key Files

| File | Purpose |
|------|---------|
| `scripts/reborn.sh` | 再起動実行（別 tmux ウィンドウで実行） |
| `.claude/skills/reload/SKILL.md` | /reload スキル定義 |
| `.claude/hooks/session-end-save-state.py` | 終了時: セッションID保存 |
| `.claude/self-reborn/handoff.md` | 引き継ぎ情報（gitignore対象） |
| `.claude/self-reborn/session_id` | セッションID（gitignore対象） |

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
