# CLAUDE.md

このファイルは、Claude Code (claude.ai/code) が本リポジトリで作業する際のガイダンスです。

## 必読（この順）

1. `../EXPERIMENT-STACK.md` — 研究全体（第1章完了・第2章方針・制約）
2. 本ファイル
3. `docs/STACK-PROFILE.md` — 本スタック固有の構成（ベースライン完成後に整備）

## 言語設定

ユーザーとのやり取り・説明・コミットメッセージ・コメントは **日本語**。コード識別子は英語可。

## リポジトリの位置づけ

| 項目 | 内容 |
|------|------|
| 研究テーマ | 技術更新に強い Web アプリ基盤の検討 |
| 章 | **第2章** — スタック比較 |
| スタック ID | **S1** — HTML/JS + Laravel API |
| 設計 | **improved 固定**（TaskService / TaskRepository を維持） |
| fork 元 | `../tech-update-task-app`（improved / S0 Blade） |
| 第1章 legacy | 本リポジトリでは扱わない。`../tech-update-task-app-legacy` は参照のみ |

**目的:** improved 設計を維持したまま、Blade をやめて **素の HTML + JavaScript（fetch）** でタスク UI を実装し、技術更新時の修正のしやすさを第2章で比較できるベースラインを作る。

## 絶対に守る制約

1. **Fat Controller 化禁止** — Service/Repository を削除・バイパスしない。
2. **ベースライン汚染禁止** — `priority` 追加等のシナリオ変更は `exp/*` のみ。`main` / `experiment-baseline-v1` に混在させない。
3. **Docker Compose のみ** — ホストで `php artisan serve` / `npm install` を実行しない。
4. **ベースライン仕様** — タスク属性は `title` / `description` / `due_date` / `status` の4項目のみ（シナリオ前）。
5. **`../EXPERIMENT-STACK.md` の第2章設計に反する変更をしない。**

## 開発環境

| 項目 | 値 |
|------|-----|
| Web | `http://localhost:8002` |
| DB 公開ポート | `5435` |
| Compose 名 | `tech-update-task-app-htmljs` |
| シードユーザー | `test@example.com` / `password` |

### 初回セットアップ

```bash
cp .env.example .env
docker compose build app
docker compose up -d
docker compose exec app php artisan key:generate
docker compose exec app php artisan migrate --seed
composer npm:docker-build
```

### よく使うコマンド

```bash
./scripts/check-quality.sh
docker compose exec app composer test
docker compose exec app composer phpstan
npm run test:api:docker
./scripts/curl-api-smoke.sh
```

## スタック固有の実装方針（S1）

### フロント

- Blade のタスク画面（`resources/views/tasks/*`）は **API 分離型に置き換え**る。
- 推奨配置: `public/app/` または `resources/static/` + nginx 配信（最終パスは `docs/STACK-PROFILE.md` に記載）。
- **素の HTML + JavaScript（fetch）** のみ。React/Vue 等の FW は使わない。
- タスク CRUD・一覧フィルタ・ソートを S0（Blade）と **機能 parity** を取る。

### バックエンド

- **Laravel REST API は improved のまま維持**（`API\TaskController` → `TaskService` → `TaskRepository`）。
- Web の `Web\TaskController` と Blade タスクルートは **削除または無効化**（API + 静的フロントに一本化）。
- 認証: **Laravel Sanctum**（設定は `docs/STACK-PROFILE.md` に記録）。

### テスト

- 既存 **PHPUnit**（Feature/API）と **Newman**（Postman）を通す。
- `postman/local.postman_environment.json` の `baseUrl` は `http://localhost:8002`。

## アーキテクチャ（improved・維持）

```text
Browser (HTML/JS)
    │ fetch / Cookie or Bearer
    ▼
API\TaskController
    ▼
TaskService
    ▼
TaskRepository → Task (Model)
```

## 実験ワークフロー

```bash
composer experiment:metrics -- --phase baseline --diff-ref experiment-baseline-v1
composer experiment:metrics -- --phase after_update --diff-ref experiment-baseline-v1
composer experiment:metrics -- --phase after_fix --diff-ref experiment-baseline-v1
composer experiment:record -- --scenario <id> --write
./scripts/publish-experiment-results.sh --scenario <id>
```

- 主指標: **`git_app`** の変更ファイル数・行数（`after_fix`）
- 通過率だけでスタック差を判定しない（第1章 priority と同様）

## ベースライン完了の定義

- [ ] HTML/JS からタスク CRUD・フィルタ・ソートが動作
- [ ] Sanctum 認証で API が使える
- [ ] `./scripts/check-quality.sh` 成功
- [ ] `experiment-baseline-v1` タグ作成
- [ ] `docs/STACK-PROFILE.md` 完成

## 関連ドキュメント

| ファイル | 内容 |
|----------|------|
| `../EXPERIMENT-STACK.md` | 研究全体 |
| `docs/STACK-PROFILE.md` | S1 固有 |
| `docs/EXPERIMENT.md` | 第1章由来の指標定義（参照） |
| `../tech-update-task-app/docs/scenarios/` | シナリオ参照（行番号は本リポジトリに読み替え） |
