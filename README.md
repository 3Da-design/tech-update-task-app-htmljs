# tech-update-task-app-htmljs

技術更新に強い Web アプリ基盤を比較する研究の **スタック S1 — HTML/JS + Laravel API** 実験台です。
improved 設計（Controller / Service / Repository 分離）を維持したまま、タスク UI を Blade から **素の HTML + JavaScript（fetch）** に置き換え、Blade 版（S0）と技術更新時の修正のしやすさを比較します。

[![CI](https://github.com/3Da-design/tech-update-task-app-htmljs/actions/workflows/ci.yml/badge.svg)](https://github.com/3Da-design/tech-update-task-app-htmljs/actions/workflows/ci.yml)

---

## 目次

1. [研究ゴールと比較設計](#研究ゴールと比較設計)
2. [アーキテクチャ](#アーキテクチャ)
3. [技術スタック](#技術スタック)
4. [クイックスタート](#クイックスタート)
5. [テストと CI](#テストと-ci)
6. [実験の進め方](#実験の進め方)
7. [更新シナリオ](#更新シナリオ)
8. [評価指標](#評価指標)
9. [ドキュメント索引](#ドキュメント索引)

---

## 研究ゴールと比較設計

| 項目 | 内容 |
|------|------|
| **章** | 第2章 — スタック比較 |
| **スタック ID** | **S1** — HTML/JS + Laravel API |
| **ゴール** | improved 設計を維持したまま、フロント方式（Blade → HTML/JS）の違いが技術更新時の影響をどう変えるかを定量的に示す |
| **本リポジトリ** | 素の HTML + JavaScript（fetch）フロント + Laravel REST API（improved 維持） |
| **ベースライン** | **`main`** および **`experiment-baseline-v1` タグ**。タスク属性は **`title` / `description` / `due_date` / `status` の 4 項目のみ**。`priority` 追加・status integer 化などの仕様変更は **`exp/*` ブランチ** で実施 |
| **対照** | S0 Blade（`tech-update-task-app`、improved・同一 API） |
| **fork 元** | `tech-update-task-app`（improved / S0 Blade） |
| **比較条件** | 同一アプリ（タスク管理）、同一 API 設計、同一 Feature テスト、フロント方式のみ差し替え |

詳細は [../EXPERIMENT-STACK.md](../EXPERIMENT-STACK.md) と [docs/STACK-PROFILE.md](docs/STACK-PROFILE.md) を参照してください。

> **第1章 legacy は扱いません。** Fat Controller 版（`tech-update-task-app-legacy`）は参照のみです。

---

## アーキテクチャ

### タスク領域（フロント分離 + improved 維持）

```text
Browser (HTML/JS — public/app/)
    │ fetch / credentials: 'include'
    │ X-XSRF-TOKEN ヘッダー（CSRF 保護）
    ▼
API\TaskController          … HTTP の受け渡しのみ
    │
    ▼
TaskService                … 認可・入力正規化・ユースケース
    │
    ▼
TaskRepositoryInterface
    │
    ▼
TaskRepository             … Eloquent による永続化
    │
    ▼
Task (Model)
```

| レイヤ | クラス／ファイル |
|--------|------------------|
| フロント | `public/app/tasks.html` / `tasks.js` / `style.css`（nginx 直配信） |
| API | `App\Http\Controllers\API\TaskController` |
| Service | `App\Services\TaskService` |
| Repository | `App\Repositories\TaskRepository` |
| Interface | `App\Repositories\Contracts\TaskRepositoryInterface` |
| DI | `App\Providers\RepositoryServiceProvider` |
| 入出力 | `StoreTaskRequest`, `UpdateTaskRequest`, `TaskResource` |

### S0 Blade との主な違い

| 観点 | S0 Blade | S1 HTML/JS（本リポジトリ） |
|------|----------|----------------------------|
| タスク UI | Blade テンプレート（サーバサイド描画） | 静的 HTML + fetch（クライアントサイド描画） |
| `Web\TaskController` | 有（Blade 返却・リダイレクト） | **削除**（API 一本化） |
| ルーティング | Web + API 二系統 | API のみ（Web は認証・プロフィールのみ） |
| CSRF | Blade の `@csrf` | `XSRF-TOKEN` Cookie → `X-XSRF-TOKEN` ヘッダー |
| ログイン画面 | Breeze Blade | 同左（Breeze Blade を継続利用） |

### 認証・プロフィール

Laravel Breeze 標準（セッション Cookie）。ログイン / 登録 / プロフィール画面は Blade のまま維持し、タスク UI のみ静的フロントに一本化しています。

### API エンドポイント

| メソッド | パス | 説明 |
|----------|------|------|
| GET | `/api/tasks` | 一覧（フィルタ・ソート対応） |
| POST | `/api/tasks` | 作成（201） |
| PUT | `/api/tasks/{id}` | 更新 |
| DELETE | `/api/tasks/{id}` | 削除（204） |

### ディレクトリ（タスク関連）

```text
public/app/                    # 静的フロント（nginx 直配信）
├── tasks.html                 # タスク一覧・CRUD の単一ページ
├── tasks.js                   # API 呼び出し・DOM 操作
└── style.css                  # スタイルシート

app/
├── Http/
│   ├── Controllers/API/TaskController.php
│   ├── Requests/              # バリデーション
│   └── Resources/             # API JSON
├── Services/TaskService.php
└── Repositories/
    ├── Contracts/TaskRepositoryInterface.php
    └── TaskRepository.php
```

---

## 技術スタック

| 区分 | 技術 |
|------|------|
| バックエンド | Laravel 13、PHP 8.4 |
| フロント（タスク） | 素の HTML + JavaScript（fetch）。React / Vue 等の FW は不使用 |
| フロント（認証） | Blade（Breeze ログイン / プロフィール） |
| 認証 | Laravel Breeze（セッション Cookie）、CSRF は `X-XSRF-TOKEN` |
| DB | PostgreSQL（Docker Compose） |
| 品質 | PHPStan (Larastan)、Laravel Pint、ESLint |
| テスト | PHPUnit、Postman / Newman |
| CI | GitHub Actions |
| 開発環境 | Docker Compose（Web `http://localhost:8002` / DB `5435`） |

---

## クイックスタート

### 前提

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) など Compose v2 対応環境
- 開発フローは **Docker Compose のみ**（ホストで `php artisan serve` は使わない。Web ポートは `8002`）
- **フロント（npm）は Docker の `node` サービスのみ**（ホストで `npm install` / `npm ci` しない）

### 初回セットアップ

```bash
cp .env.example .env

docker compose build app
docker compose up -d

docker compose exec app php artisan key:generate
docker compose exec app php artisan migrate --seed

# フロント資産（ログイン画面など @vite 用）
composer npm:docker-build
```

ブラウザで `http://localhost:8002` を開くと `/app/tasks.html` にリダイレクトされます。
未認証の場合はログイン画面へ遷移します。シードユーザー: `test@example.com` / `password`

### よく使うコマンド

```bash
docker compose logs -f
docker compose down              # DB ボリュームは残る
docker compose down -v           # DB ごと削除
```

### API の疎通確認

```bash
chmod +x scripts/curl-api-smoke.sh
./scripts/curl-api-smoke.sh
```

`http_code` が `000` のときは Docker 未起動・URL 誤り・ポート競合を確認してください。

---

## テストと CI

### ローカル一括（推奨）

```bash
./scripts/check-quality.sh
```

実行内容: PHPStan → npm ci → ESLint → Vite build → PHPUnit → Newman

### フロントエンド（Docker のみ）

ホストに Node が入っていても、**依存のインストール・ビルドはコンテナ内だけ**で行います。

```bash
composer npm:docker-ci      # コンテナ内 npm ci
composer npm:docker-build   # 上記 + npm run build
docker compose --profile node run --rm node npm run lint
```

### 個別（PHP / API）

```bash
docker compose exec app composer phpstan
docker compose exec app composer test
npm run test:api:docker
```

### 主要テスト

| テスト | ファイル | 内容 |
|--------|----------|------|
| API CRUD | `tests/Feature/TaskApiTest.php` | タスク作成・更新・削除・一覧 |
| API フィルタ | `tests/Feature/TaskListFilterTest.php` | 一覧のフィルタ・ソート |
| Web リダイレクト | `tests/Feature/TaskWebTest.php` | `/` → `/app/tasks.html` リダイレクト |
| 認証 | `tests/Feature/Auth/*.php` | Breeze 標準 |
| Newman | `postman/Task-API.postman_collection.json` | API アサーション |

---

## 実験の進め方

### 1. ベースラインの確立

CI 緑の状態で:

```bash
./scripts/check-quality.sh
composer experiment:metrics -- --phase baseline --diff-ref experiment-baseline-v1
git tag -a experiment-baseline-v1 -m "Experiment baseline: S1 HTML/JS + Laravel API"
```

メトリクス JSON は `experiment/metrics/` に出力されます（Git 管理外）。

### 2. 更新シナリオの実施

[docs/scenarios/](docs/scenarios/) の手順に従い、ブランチで変更を適用します。

```bash
git checkout -b exp/my-scenario experiment-baseline-v1
# … シナリオに沿って変更 …
composer experiment:metrics -- --phase after_update --diff-ref experiment-baseline-v1
# … テスト・コードを修正 …
./scripts/check-quality.sh
composer experiment:metrics -- --phase after_fix --diff-ref experiment-baseline-v1
```

### 3. 記録・公開

```bash
composer experiment:record -- --scenario <id> --write
./scripts/publish-experiment-results.sh --scenario <id>
```

### 4. S0 Blade との比較

S0 Blade（`tech-update-task-app`）で **同じシナリオ・同じ手順** を繰り返し、主指標 `git_app` の変更ファイル数・行数を比較します。

---

## 更新シナリオ

本研究の **主シナリオは 3 件**。いずれも `experiment-baseline-v1` から `exp/*` ブランチで実施します。手順は S0 の [docs/scenarios/](../tech-update-task-app/docs/scenarios/) を参照し、**行番号は本リポジトリに読み替え**ます。

| # | シナリオ | ドキュメント |
|---|----------|--------------|
| 1 | API 仕様変更: status integer 化 | `api-spec-change-status-int.md` |
| 2 | API 仕様変更: priority 追加 | `api-spec-change-priority.md` |
| 3 | DB / クエリ変更（タイトル検索） | `db-schema-change.md` |

---

## 評価指標

**主指標は修正工数**（`after_fix` フェーズの変更ファイル数・行数、`git_app`）。API 仕様変更シナリオでは、スタック間で **テスト通過率が同一になることがある** ため、通過率だけでスタック差を評価しません。

| 優先 | 指標 | 概要 | 取得 |
|------|------|------|------|
| **1** | **修正工数** | 変更ファイル数・追加/削除行 | `composer experiment:metrics -- --diff-ref experiment-baseline-v1` の `git_app.*`（**after_fix**） |
| 2 | 更新直後のテスト失敗数 | PHPUnit / Newman の fail 件数 | 同上（**after_update**） |
| 3 | 作業時間 | 分 | 手動記録 |
| 4 | エラー発生率 | PHPStan 件数、CI 失敗ジョブ | スクリプト + 手動 |

定義の詳細: [docs/EXPERIMENT.md](docs/EXPERIMENT.md)

---

## ドキュメント索引

| ドキュメント | 内容 |
|--------------|------|
| [../EXPERIMENT-STACK.md](../EXPERIMENT-STACK.md) | 研究全体（第2章スタック比較） |
| [docs/STACK-PROFILE.md](docs/STACK-PROFILE.md) | S1 固有の構成・API・手動確認手順 |
| [docs/EXPERIMENT.md](docs/EXPERIMENT.md) | 実験設計・指標・フェーズ（第1章由来） |
| [docs/scenarios/](docs/scenarios/) | 更新シナリオ手順 |
| [experiment/results/](experiment/results/) | シナリオ結果（publish 先） |

---

## ライセンス

MIT（Laravel プロジェクトスケルトンに準拠）
