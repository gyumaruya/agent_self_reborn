# Current Sprint

## Scrum Environment

- Backlog: `docs/scrum/backlog.md`
- Sprint tracking: `docs/scrum/sprints/current.md`
- Code review: Pull Requests (via `gh` CLI)

## Sprint 1 -- started 2026-02-22

### Goal

Claude Code セルフリスタート MVP を実装する。Claude Code が自身を停止・再起動でき、セッション間で状態を引き継げる最小構成を構築する。

### Backlog

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | シェルラッパースクリプト作成 | done | scripts/claude-self-reborn.sh, scripts/start-tmux.sh |
| 2 | /reload スキル作成 | done | .claude/skills/reload/SKILL.md |
| 3 | SessionEnd hook 作成 | done | .claude/hooks/session-end-save-state.py |
| 4 | SessionStart hook 作成 | done | .claude/hooks/session-start-inject-context.py |
| 5 | 状態管理ファイル設計 | done | .claude/self-reborn/ + .gitignore + settings.json |
| 6 | 動作検証 | done | bash テスト4件 + Python テスト6件 全通過 |

### Blockers

None.

### Log

- 2026-02-22 : Sprint 1 開始。調査完了、MVP 実装開始。
