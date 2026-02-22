# claude_self_reborn

Claude Code が自身を停止し、再起動できるようにするラッパーシステム。

## 何ができるのか

通常の Claude Code は、1セッションで終わる。コンテキストが溜まったら手動で再起動するしかない。

**self-reborn** を使うと:

- Claude Code が **自分の判断で** プロセスを再起動できる
- 再起動後、**前のセッションを引き継いで** 続きから作業できる
- **なぜ再起動したか** をファイルに残し、次の自分に伝えられる
- tmux で動かせば、ターミナルを閉じても裏で動き続ける

## 通常の Claude Code との違い

```
【通常】
ユーザー → claude 起動 → 作業 → 終了 → ユーザーが再起動 → 新しいセッション

【self-reborn】
ユーザー → start-tmux.sh → claude 起動
                             ↓
                          作業中...
                             ↓
                    Claude が /reload を実行
                             ↓
                   ラッパーが自動で再起動
                             ↓
                    --resume で前回セッション継続
                    + 前回のコンテキストが注入される
                             ↓
                          作業継続...
```

**変わること:**
- Claude が「コンテキストが重い」「設定を変えた」「フェーズを変えたい」時に自分で再起動できる
- ユーザーの介入なしにセッションを切り替えられる
- セッション間で「なぜ再起動したか」「何をしていたか」が引き継がれる

**変わらないこと:**
- Claude Code 自体には一切変更を加えていない
- 通常の `claude` コマンドとしても使える（ラッパーなしで動く）
- 既存の hooks や skills と共存する

## ワークフロー

### 1. 起動

```bash
# tmux セッション内で起動（推奨）
./scripts/start-tmux.sh

# tmux を使わない場合
./scripts/claude-self-reborn.sh
```

### 2. 通常どおり作業

Claude Code がいつもどおり起動する。何も変わらない。

### 3. Claude が再起動を判断

Claude が自分で「再起動すべき」と判断した時:

```bash
# 1. 理由を書く（次の自分へのメッセージ）
echo "コンテキストが80%超えた。不要な履歴を切り捨てるため再起動" \
  > .claude/self-reborn/restart_reason

# 2. 引き継ぎたい情報を書く
echo "Sprint 1 の item 3 を実装中。tests/test_api.py の修正が残っている" \
  > .claude/self-reborn/context.md

# 3. 再起動シグナルを送る
kill -HUP $PPID
```

### 4. 自動再起動

ラッパーが exit code 129 を検出し、0.5秒後に `claude --resume <session_id>` で再起動。

再起動後の Claude には以下が注入される:
```
[Self-Reborn] Restarted. Reason: コンテキストが80%超えた。不要な履歴を切り捨てるため再起動
[Self-Reborn] Previous context: Sprint 1 の item 3 を実装中。tests/test_api.py の修正が残っている
[Self-Reborn] Session #4 (restarted 3 times)
```

### 5. tmux でのバックグラウンド動作

```bash
# デタッチ（裏で動き続ける）
Ctrl-b d

# 再アタッチ
tmux attach -t claude-reborn

# セッション終了
tmux kill-session -t claude-reborn
```

## システム構成

```
scripts/
  claude-self-reborn.sh    # 再起動ラッパー（メインループ）
  start-tmux.sh            # tmux セッション起動

.claude/
  settings.json            # hooks 登録
  skills/reload/SKILL.md   # /reload スキル定義
  hooks/
    session-end-save-state.py       # 終了時: セッションID保存
    session-start-inject-context.py # 起動時: 前回の状態注入
  self-reborn/             # ランタイム状態（gitignore対象）
    session_id             # 現在のセッションID
    restart_reason         # 再起動理由（次回起動時に消費）
    context.md             # 引き継ぎコンテキスト（次回起動時に消費）
    crash_count            # 連続クラッシュ回数
    restart.log            # 再起動ログ
    session_history.jsonl  # セッション履歴

tests/
  test_wrapper.sh          # ラッパーの統合テスト (4件)
  test_hooks.py            # hooks の単体テスト (6件)
```

## 安全機構

| 機構 | 説明 |
|------|------|
| **クラッシュカウンター** | 連続クラッシュが5回（デフォルト）でラッパーが停止 |
| **指数バックオフ** | クラッシュ時の再起動間隔: 2s → 4s → 8s → 16s → 32s → 60s（上限） |
| **正常終了で停止** | exit code 0 でラッパーが完全停止（無限ループしない） |
| **意図的再起動はリセット** | exit 129 (SIGHUP) ではクラッシュカウンターがリセット |
| **ラッパーなしは安全** | ラッパーなしで SIGHUP を送るとセッションが終了するだけ |

## 制約と既知の制限

### 技術的制約

- **tmux 依存（推奨）**: バックグラウンド動作には tmux が必要。なくても動くがターミナルを閉じると止まる
- **bash 3.2 互換**: macOS デフォルトの古い bash でも動作する（`**` 演算子不使用、空配列対策済み）
- **`--resume` と `-p` の非互換**: セッション再開時にプロンプト注入ができないため、SessionStart hook の `additionalContext` 経由でコンテキストを渡している

### 設計上の制約

- **Claude Code 自体は無変更**: 外部ラッパーのみ。Claude Code のアップデートで内部仕様が変わっても影響を受けにくい
- **セッションファイルは Claude Code 依存**: `~/.claude/projects/<dir>/<session_id>.jsonl` に保存される。Claude Code のセッション管理仕様が変わると壊れる可能性あり
- **`kill -HUP $PPID`**: 親プロセス（ラッパーの bash）に SIGHUP を送る設計。Docker や特殊な環境ではプロセスツリーが異なる可能性あり
- **レート制限未対応**: 長時間連続実行で API レート制限に当たった場合のリカバリは未実装（将来対応予定）

### 自己改善ループとしての制約

- **現時点では「再起動できる」だけ**: 「何をきっかけに再起動すべきか」のポリシーは Claude の判断に委ねられている。自動トリガー（コンテキスト使用率、タスク完了検出）は未実装
- **状態の引き継ぎは手動**: Claude が `restart_reason` と `context.md` に明示的に書かないと引き継がれない
- **スキル自動リロード**: `/reload` で Claude Code が再起動すると `.claude/` 配下のスキルや設定が再読み込みされる -- これがスキル開発時に価値を持つ

## 設定

環境変数で挙動をカスタマイズ:

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `CLAUDE_SELF_REBORN_MAX_CRASHES` | `5` | 連続クラッシュ上限 |
| `CLAUDE_SELF_REBORN_BACKOFF` | `2` | 初回バックオフ秒数 |
| `CLAUDE_SELF_REBORN_STATE_DIR` | `.claude/self-reborn` | 状態ディレクトリ |

## テスト

```bash
# ラッパーの統合テスト
bash tests/test_wrapper.sh

# hooks の単体テスト
python3 tests/test_hooks.py
```
