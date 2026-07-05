# S1 スタックプロファイル — HTML/JS + Laravel API

## 概要

| 項目 | 内容 |
|------|------|
| スタック ID | **S1** |
| 名称 | HTML/JS + Laravel API |
| 設計 | improved（TaskService / TaskRepository 維持） |
| フロント | 素の HTML + JavaScript（fetch API） |
| バックエンド | Laravel 13 REST API |
| 認証 | Laravel Sanctum 同等（セッション Cookie 方式） |
| fork 元 | `tech-update-task-app`（S0 improved） |

## アーキテクチャ

```text
Browser (HTML/JS — public/app/)
    │ fetch / credentials: 'include'
    │ X-XSRF-TOKEN ヘッダー（CSRF 保護）
    ▼
API\TaskController
    ▼
TaskService
    ▼
TaskRepository → Task (Model)
```

### S0 Blade との主な違い

| 観点 | S0 Blade | S1 HTML/JS |
|------|----------|------------|
| タスク UI | Blade テンプレート（サーバサイド描画） | 静的 HTML + fetch（クライアントサイド描画） |
| Web\TaskController | 有（Blade 返却・リダイレクト） | **削除**（API 一本化） |
| ルーティング | Web + API 二系統 | API のみ（Web は認証・プロフィールのみ） |
| 認証 | Breeze セッション（Web + API） | セッション Cookie で API アクセス |
| CSRF | Blade の `@csrf` | `XSRF-TOKEN` Cookie → `X-XSRF-TOKEN` ヘッダー |
| ログイン画面 | Breeze Blade（維持） | 同左（Blade ログインを継続利用） |

## ポート・コンテナ構成

| サービス | コンテナ名 | ポート |
|----------|-----------|--------|
| Nginx | `tech-update-task-app-htmljs-nginx` | 8002 |
| PHP-FPM | `tech-update-task-app-htmljs-php` | 9000（内部） |
| PostgreSQL | `tech-update-task-app-htmljs-postgres` | 5435 |
| Node（ビルド時のみ） | profile: node | — |

## ファイル構成

### フロントエンド（タスク UI）

```text
public/app/
├── tasks.html   … タスク一覧・CRUD の単一ページ
├── tasks.js     … API 呼び出し・DOM 操作
└── style.css    … スタイルシート
```

- Vite / Webpack を使わない。`public/app/` に静的ファイルを配置し nginx が直接配信。
- Blade のタスクビュー（`resources/views/tasks/`）は削除済み。

### バックエンド（API）

```text
app/Http/Controllers/API/TaskController.php  … REST API エンドポイント
app/Services/TaskService.php                 … ビジネスロジック
app/Repositories/TaskRepository.php          … データアクセス
app/Repositories/Contracts/TaskRepositoryInterface.php
app/Http/Resources/TaskResource.php          … JSON レスポンス整形
app/Http/Requests/                           … バリデーション
```

### 削除・無効化したファイル

| ファイル | 理由 |
|----------|------|
| `app/Http/Controllers/Web/TaskController.php` | API 一本化のため削除 |
| `resources/views/tasks/*.blade.php` | 静的 HTML に置き換え |

### 残存する Blade

| ファイル | 理由 |
|----------|------|
| `resources/views/auth/*.blade.php` | Breeze ログイン / 登録画面 |
| `resources/views/profile/*.blade.php` | プロフィール画面 |
| `resources/views/layouts/*.blade.php` | 上記ページのレイアウト |

## API エンドポイント

| メソッド | パス | 説明 |
|----------|------|------|
| GET | `/api/tasks` | 一覧（フィルタ・ソート対応） |
| POST | `/api/tasks` | 作成（201） |
| PUT | `/api/tasks/{id}` | 更新 |
| DELETE | `/api/tasks/{id}` | 削除（204） |

### クエリパラメータ（GET /api/tasks）

| パラメータ | 型 | 説明 |
|------------|-----|------|
| `title` | string | 部分一致検索 |
| `status` | string | 完全一致（`todo` / `in_progress` / `done`） |
| `due_date_sort` | string | `asc`（昇順・NULL 先頭）/ `desc`（降順） |

## 認証方式

### セッション Cookie 方式（Sanctum 同等）

1. ブラウザで `/login`（Blade）にアクセスし、フォームログイン
2. Laravel がセッション Cookie（`laravel_session`）と `XSRF-TOKEN` Cookie を発行
3. `public/app/tasks.html` にリダイレクト
4. JavaScript が `fetch` で API を呼ぶ際:
   - `credentials: 'include'` でセッション Cookie を送信
   - `X-XSRF-TOKEN` ヘッダーに `XSRF-TOKEN` Cookie の値をデコードして送信
5. 401 応答時は `/login` にリダイレクト

### ミドルウェア構成（bootstrap/app.php）

API ミドルウェアスタックに以下を追加済み:

```php
$middleware->api(prepend: [
    EncryptCookies::class,
    AddQueuedCookiesToResponse::class,
    StartSession::class,
    PrefersJsonResponses::class,
]);
```

## テスト構成

| テスト | ファイル | 内容 |
|--------|----------|------|
| API CRUD | `tests/Feature/TaskApiTest.php` | 8 テスト |
| API フィルタ | `tests/Feature/TaskListFilterTest.php` | 4 テスト（API のみ） |
| Web リダイレクト | `tests/Feature/TaskWebTest.php` | 3 テスト（リダイレクト確認） |
| 認証 | `tests/Feature/Auth/*.php` | Breeze 標準テスト |
| Newman | `postman/Task-API.postman_collection.json` | 13 assertions |

### S0 からの変更点

- `TaskWebTest`: Blade 描画テスト → リダイレクトテストに変更
- `TaskListFilterTest`: Web フィルタテスト（4 件）を削除、API フィルタテスト（4 件）を維持

## 品質ゲート

```bash
./scripts/check-quality.sh
```

実行順: PHPStan → npm ci → ESLint → Vite build → PHPUnit → Newman

## 開発手順

### 初回セットアップ

```bash
cp .env.example .env
docker compose build app
docker compose up -d
docker compose exec app php artisan key:generate
docker compose exec app php artisan migrate --seed
composer npm:docker-build
```

### シードユーザー

| メール | パスワード |
|--------|-----------|
| `test@example.com` | `password` |

### 手動確認手順

1. `docker compose up -d` でスタック起動
2. ブラウザで `http://localhost:8002` にアクセス → `/app/tasks.html` にリダイレクト
3. API 未認証のため `/login` にリダイレクト
4. `test@example.com` / `password` でログイン
5. タスク一覧が表示される
6. 「新規作成」→ タイトル・ステータスを入力 → 「保存」→ 一覧に追加
7. 「編集」→ フィールド変更 → 「保存」→ 一覧に反映
8. 「削除」→ 確認ダイアログ → 一覧から消去
9. フィルタ（タイトル検索、ステータス選択）→ 「適用」→ 絞り込み
10. 期限ソート（昇順 / 降順）→ 「適用」→ 並び替え
11. 「ログアウト」→ ログイン画面に遷移

## ベースライン仕様

- タスク属性: `title` / `description` / `due_date` / `status` の **4 項目のみ**
- `priority` 等のシナリオ変更は未実装
- ベースラインタグ: `experiment-baseline-v1`
