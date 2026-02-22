# claude_self_reborn

Claude Code が自身を停止し、再起動できるようにする仕組み。

## 何ができるのか

通常の Claude Code は、1セッションで終わる。コンテキストが溜まっても、設定を変えても、手動で再起動するしかない。

**self-reborn** を使うと、Claude Code が自分の判断で再起動し、前のセッションを引き継いで作業を続けられる。

## 通常の Claude Code との違い

```
【通常】
ユーザー → claude 起動 → 作業 → 終了 → ユーザーが手動で再起動

【self-reborn】
ユーザー → tmux で claude 起動 → 作業
                                    ↓
                          Claude が「再起動したい」と判断
                                    ↓
                          handoff.md に引き継ぎ情報を書く
                          別の tmux ウィンドウで reborn.sh を起動
                                    ↓
                          reborn.sh が:
                            1. 元のウィンドウの Claude を Ctrl+C で停止
                            2. 停止を確認
                            3. --resume で同じセッションを再起動
                            4. 「handoff.md を読んで続きをやって」と入力
                            5. 自分のウィンドウを閉じる
                                    ↓
                          Claude が handoff.md を読んで作業継続
```

**変わること:**
- Claude が自分で再起動を判断し、実行できる
- 再起動の理由と引き継ぎ情報が handoff.md 経由で次の自分に伝わる
- ユーザーの介入が不要

**変わらないこと:**
- Claude Code 自体に変更なし（外部スクリプトのみ）
- 通常の `claude` コマンドとして普通に使える
- tmux なしでも動く（再起動機能だけが使えない）

## ワークフロー

### 1. tmux 内で普通に Claude を起動

```bash
tmux
claude
```

特別な起動方法は不要。普通に使う。

### 2. Claude が再起動を実行（/reload）

Claude が再起動すべきと判断した時、以下を実行する:

```bash
# 1. 引き継ぎ情報を書く
mkdir -p .claude/self-reborn
cat > .claude/self-reborn/handoff.md << 'EOF'
# Handoff

## Restart Reason
コンテキストが重くなったため、不要な履歴を切り捨てる

## Current Task
Sprint 1 の item 3 を実装中

## Next Steps
- tests/test_api.py の修正を完了する
- lint を通す

## Important Context
- API の認証方式は JWT に決定済み
- データベースは SQLite を使用
EOF

# 2. セッションIDを取得
SESSION_ID=$(cat .claude/self-reborn/session_id)

# 3. 別の tmux ウィンドウで reborn.sh を起動
tmux new-window -n reborn "./scripts/reborn.sh '$TMUX_PANE' '$SESSION_ID' '$(pwd)'"
```

この後、reborn.sh が Claude を停止 → 再起動 → handoff.md の読み込みを指示する。

### 3. 再起動後

Claude は前のセッション履歴を持った状態で再起動し、最初のメッセージとして
「handoff.md を読んで続きをやって」と入力される。

## ファイル構成

```
scripts/
  reborn.sh                # 再起動実行スクリプト（別 tmux ウィンドウで実行）

.claude/
  settings.json            # hooks 登録
  skills/reload/SKILL.md   # /reload スキル定義
  hooks/
    session-end-save-state.py   # 終了時: セッションID保存
  self-reborn/                  # ランタイム状態（gitignore 対象）
    session_id                  # 現在のセッションID
    handoff.md                  # 引き継ぎ情報（次回起動時に読まれる）
    session_history.jsonl       # セッション履歴

tests/
  test_wrapper.sh          # reborn.sh のテスト (5件)
  test_hooks.py            # hooks のテスト (3件)
```

## reborn.sh の動作

`scripts/reborn.sh <tmux-pane> <session-id> <project-dir>` は:

1. **2秒待つ** -- Claude が最後の出力を終えるのを待つ
2. **Ctrl+C を送信** -- 元のペインの Claude を停止（5秒、15秒後に再送）
3. **停止を確認** -- tmux の `pane_current_command` をポーリング（最大30秒）
4. **再起動** -- `claude --resume <session-id>` を元のペインで実行
5. **初回プロンプト送信** -- handoff.md がある場合、読み込み指示を送信
6. **自己終了** -- ウィンドウを閉じる

## 制約

### 技術的制約

| 制約 | 理由 |
|------|------|
| **tmux 必須**（再起動機能に限り） | 別ウィンドウから元のペインを操作する必要がある |
| **`--resume` と `-p` は非互換** | Claude Code の仕様。初回プロンプトは tmux send-keys で送信 |
| **起動待ちは固定 8秒** | Claude の起動完了を検出する手段がないため |
| **bash 3.2 互換** | macOS デフォルトの古い bash でも動作する |

### 設計上の制約

| 制約 | 説明 |
|------|------|
| **「いつ再起動するか」は Claude の判断** | 自動トリガーは未実装。Claude が明示的に /reload を使う |
| **handoff.md は手動作成** | Claude が自分で書く。書かなければ引き継ぎなしで再起動 |
| **レート制限未対応** | API レート制限に当たった場合のリカバリは未実装 |
| **1ペイン1Claude** | 同じペインで複数の Claude を同時実行するとおかしくなる |

### セキュリティ

- reborn.sh は指定されたペインにのみ干渉する
- Claude Code 自体には一切の変更なし
- セッションIDはローカルファイルに保存（gitignore対象）

## 設定

特別な設定は不要。唯一の設定は `.claude/settings.json` の SessionEnd hook:

```json
{
  "hooks": {
    "SessionEnd": [{
      "type": "command",
      "command": "python3 .claude/hooks/session-end-save-state.py"
    }]
  }
}
```

## テスト

```bash
# reborn.sh のテスト
bash tests/test_wrapper.sh

# hooks のテスト
python3 tests/test_hooks.py
```
