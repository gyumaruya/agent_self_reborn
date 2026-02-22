# claude_self_reborn

Claude Code が自身を停止・再起動できる仕組み。詳細は `README.md` を参照。

## Self-Reborn: 使い方

### 前提

- tmux 内で実行していること

### 再起動

`/reload` スキルを使う。スキルが以下を実行する:

1. handoff.md に引き継ぎ情報を書く
2. セッション ID を取得
3. 一時スクリプトを生成し tmux 別ウィンドウで実行
4. 一時スクリプトが Claude を停止 → `--resume` で再起動 → handoff プロンプト送信

### Key Files

| File | Purpose |
|------|---------|
| `reload/SKILL.md` | /reload スキル（再起動の全手順） |
| `.claude/hooks/session-end-save-state.py` | 終了時: セッションID保存 |
| `.claude/self-reborn/handoff.md` | 引き継ぎ情報（gitignore 対象） |
| `.claude/self-reborn/session_id` | セッションID（gitignore 対象） |

## Scrum

This project uses Scrum for development management.

### Scrum Environment

- **Backlog**: `docs/scrum/backlog.md`
- **Sprint tracking**: `docs/scrum/sprints/current.md`
- **Sprint archive**: `docs/scrum/sprints/YYYY-MM-DD_sprint-NNN/`

### Automatic Ceremony Flow

1. Stakeholder desire -> PO creates backlog items -> Planning -> Dev implements
2. Increment ready -> Review -> stakeholder gives feedback
3. Review done -> Retro -> SM improves organization -> archive sprint
