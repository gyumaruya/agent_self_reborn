# Decision Log

## 2026-02-22 - カスタム MVP を選択（既存 Ralph 不採用）
**Context**: 既存の Ralph, Continuous-Claude-v3 等の選択肢を調査
**Decision**: 独自 MVP を実装する
**Rationale**: 既存プロジェクトは「連続実行」目的で設計されており、「自己判断でリスタートして自己改善する」目的にはミスマッチ。コアメカニズムは50行の bash で実装可能。既存フレームワークとの統合性を優先。
