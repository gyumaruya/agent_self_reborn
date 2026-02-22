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
                          /reload スキルを実行:
                            1. handoff.md に引き継ぎ情報を書く
                            2. 一時スクリプトを生成
                            3. tmux の別ウィンドウでスクリプトを起動
                                    ↓
                          一時スクリプトが:
                            a. 元のウィンドウの Claude を Ctrl+C で停止
                            b. 停止を確認
                            c. --resume で同じセッションを再起動
                            d. 「handoff.md を読んで続きをやって」と入力
                            e. 自分のウィンドウを閉じて自己削除
                                    ↓
                          Claude が handoff.md を読んで作業継続
```

**変わること:**
- Claude が自分で再起動を判断し、実行できる
- 再起動の理由と引き継ぎ情報が handoff.md 経由で次の自分に伝わる
- ユーザーの介入が不要

**変わらないこと:**
- Claude Code 自体に変更なし（スキルと hook のみ）
- 通常の `claude` コマンドとして普通に使える
- tmux なしでも動く（再起動機能だけが使えない）

## ワークフロー

### 1. tmux 内で普通に Claude を起動

```bash
tmux
claude
```

特別な起動方法は不要。普通に使う。

### 2. Claude が /reload を実行

Claude が再起動すべきと判断した時、`/reload` スキルに従って:

1. `$TMUX_PANE` を確認（tmux 内か検証）
2. `.claude/self-reborn/handoff.md` に引き継ぎ情報を書く
3. セッション ID を取得
4. 一時スクリプトを生成し `tmux new-window` で実行

全てのステップは Claude Code 自身が bash で実行する。外部スクリプトは不要。

### 3. 再起動後

Claude は前のセッション履歴を持った状態で再起動し、最初のメッセージとして
「handoff.md を読んで続きをやって」と入力される。

## ファイル構成

```
reload/
  SKILL.md                 # /reload スキル（再起動の全手順を定義）

.claude/
  settings.json            # hooks 登録
  hooks/
    session-end-save-state.py   # 終了時: セッションID保存
  self-reborn/                  # ランタイム状態（gitignore 対象）
    session_id                  # 現在のセッションID
    handoff.md                  # 引き継ぎ情報（次回起動時に読まれる）
    session_history.jsonl       # セッション履歴
```

## /reload スキルの動作

Claude Code が `/reload` を実行すると:

1. **tmux 確認** -- `$TMUX_PANE` が空なら中止
2. **handoff.md 作成** -- 再起動理由、現在のタスク、次のステップ、重要なコンテキストを記載
3. **セッション ID 取得** -- `.claude/self-reborn/session_id` から読み取り
4. **一時スクリプト生成** -- `/tmp/claude-reborn-XXXXXX.sh` を作成
5. **別ウィンドウで実行** -- `tmux new-window` でスクリプトを起動

一時スクリプトの動作:
- 2秒待機 → 元のペインに Ctrl+C 送信 → 停止確認（最大30秒ポーリング）
- `claude --resume <session-id>` を元のペインで実行
- 8秒待機 → handoff プロンプト送信
- 自己削除して終了

## 制約

### 技術的制約

| 制約 | 理由 |
|------|------|
| **tmux 必須**（再起動機能に限り） | 別ウィンドウから元のペインを操作する必要がある |
| **`--resume` と `-p` は非互換** | Claude Code の仕様。初回プロンプトは tmux send-keys で送信 |
| **起動待ちは固定 8秒** | Claude の起動完了を検出する手段がないため |

### 設計上の制約

| 制約 | 説明 |
|------|------|
| **「いつ再起動するか」は Claude の判断** | 自動トリガーは未実装。Claude が明示的に /reload を使う |
| **handoff.md は Claude が書く** | 書かなければ引き継ぎなしで再起動 |
| **レート制限未対応** | API レート制限に当たった場合のリカバリは未実装 |

### セキュリティ

- 一時スクリプトは実行後に自己削除
- 指定されたペインにのみ干渉
- Claude Code 自体に変更なし
- セッション ID はローカルファイルに保存（gitignore 対象）

## テスト

```bash
# hooks のテスト
python3 tests/test_hooks.py
```

## インストール

他のプロジェクトで使う場合:

```bash
npx skills add <owner>/claude_self_reborn
```
