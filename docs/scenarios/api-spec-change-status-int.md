# シナリオ: API 仕様変更 — 既存属性の型変更（`api-spec-change-status-int`）

## 目次

- [0. この実験について](#0-この実験について)
- [1. 概要](#1-概要)
- [2. 事前条件チェック](#2-事前条件チェック)
- [3. 修正対象ファイル一覧](#3-修正対象ファイル一覧)
- [4. 実施手順](#4-実施手順)
  - [Phase 0: ブランチ作成](#phase-0-ブランチ作成)
  - [Phase 1: baseline メトリクス](#phase-1-baseline-メトリクス)
  - [Phase 2: 変更適用（テスト・Postman 未着手）](#phase-2-変更適用テストpostman-未着手)
  - [Phase 3: after_update メトリクス](#phase-3-after_update-メトリクス)
  - [Phase 4: テスト・Postman 修正 → CI 緑](#phase-4-テストpostman-修正-ci-緑)
  - [Phase 5: after_fix メトリクス・記録](#phase-5-after_fix-メトリクス・記録)
- [5. 完了条件](#5-完了条件)
- [6. 触らないファイルとその理由](#6-触らないファイルとその理由)
- [関連](#関連)

## 0. この実験について

本実験は、タスクの `status` を string（`todo` / `in_progress` / `done`）から integer（`0` / `1` / `2`）へ変更する破壊的 API 仕様変更を適用し、その波及範囲を計測する。既存フィールドの型変更は、属性追加（priority）や DB スキーマ変更（タイトル検索）と対比し、技術更新時の修正コスト・失敗パターンの違いを評価するのに適している。improved 構成では Controller は HTTP 受け渡しのみとし、正規化は `TaskService`、永続化・一覧クエリは `TaskRepository`、HTTP バリデーションは FormRequest×3、表示ラベルは `config/task.php` と静的フロント（`public/app/tasks.html` / `tasks.js`）に修正が集まる想定である。`TaskResource` は Model の integer cast により JSON も自動的に int になるため触らない。

## 1. 概要

| 項目 | 値 |
| --- | --- |
| リポジトリ | tech-update-task-app-htmljs（S1 / improved） |
| 実験の内容 | `status` を string から integer（0/1/2）へ変更 |
| ブランチ名 | exp/api-spec-change-status-int |
| 参照MD | docs/scenarios/api-spec-change-status-int.md |

## 2. 事前条件チェック

- [ ]  experiment-baseline-v1 または CI 緑 — 変更前の正しいベースラインと diff 比較の基準点が必要なため
- [ ]  Docker 起動 — `docker compose exec app` でマイグレーション・テスト・Newman を実行するため
- [ ]  PostgreSQL（status数値化・タイトル検索のみ） — マイグレーションが PostgreSQL 専用 `ALTER COLUMN ... USING CASE` を使うため

## 3. 修正対象ファイル一覧

| # | ファイルパス | 修正箇所 | フェーズ | 作業内容 | 解説（なぜ触るか） |
| --- | --- | --- | --- | --- | --- |
| 1 | `database/migrations/*_change_status_to_integer_on_tasks_table.php` | `up()` / `down()` | 2 | 新規作成 | DB カラム型変更と既存データ移行のため |
| 2 | `config/task.php` | `status_values`, `status_labels` | 2 | int マッピング定義 | 全層が参照する status の正規値・表示ラベルの単一ソース |
| 3 | `app/Models/Task.php` | PHPDoc 15行目、`casts()` | 2 | integer cast 追加 | Eloquent が status を int として扱うため |
| 4 | `app/Http/Requests/StoreTaskRequest.php` | `rules()` 29行目 | 2 | `string` → `integer` | POST 入力の HTTP 境界バリデーション |
| 5 | `app/Http/Requests/UpdateTaskRequest.php` | `rules()` 29行目 | 2 | `string` → `integer` | PUT 入力の HTTP 境界バリデーション |
| 6 | `app/Http/Requests/IndexTaskRequest.php` | `rules()` 43行目 | 2 | `string` → `integer` | 一覧フィルタ `?status=` のバリデーション |
| 7 | `app/Services/TaskService.php` | `normalizeListFilters()` 74–92行目、`normalizeTaskPayload()` 126行前 | 2 | int 正規化ロジック | Controller を触らずユースケース層で型を揃えるため |
| 8 | `app/Repositories/TaskRepository.php` | `getFiltered()` 20–23行目 | 2 | `is_string` → `is_int` | 一覧クエリの status 比較を int に合わせるため |
| 9 | `app/Repositories/Contracts/TaskRepositoryInterface.php` | PHPDoc 11行目 | 2 | `status?: string` → `status?: int` | フィルタ型の契約を実装と一致させるため |
| 10 | `public/app/tasks.html` | フィルタ select 44–49行目、モーダル select 100–104行目 | 2 | option value=int、表示=labels | フィルタ・作成編集フォームの送信値を int にするため |
| 11 | `public/app/tasks.js` | `STATUS_LABELS` 追加、`renderTasks()` 106行目、`openCreateModal()` 136行目、`saveTask()` 164行目 | 2 | int value 送信 + ラベル表示 | 一覧表示を人間可読にし、送信値を int に揃えるため |
| 12 | `tests/Feature/TaskApiTest.php` | 全 `status` 参照（39, 54, 67, 78, 93, 99, 111, 125行目ほか） | 4 | 期待値を int に | API テストを新仕様に合わせるため |
| 13 | `tests/Feature/TaskListFilterTest.php` | 42行目のクエリ、73–95行目の seed | 4 | `?status=2` 等に変更 | status フィルタテストを int クエリに合わせるため |
| 14 | `postman/Task-API.postman_collection.json` | 195, 255行目の request body | 4 | `"status": 0` / `1` に変更 | Newman が新 API 仕様で通るようにするため |

## 4. 実施手順

### Phase 0: ブランチ作成

**この Phase の目的:** 実験用ブランチを baseline タグから切り、以降の変更を独立して計測できるようにする。

**Step 0-1.** 実験ブランチを作成する。

```bash
git checkout -b exp/api-spec-change-status-int experiment-baseline-v1
```

---

### Phase 1: baseline メトリクス

**この Phase の目的:** 変更前の状態を記録し、あとで diff 比較できるようにする。

**Step 1-1.** baseline フェーズのメトリクスを取得する。

```bash
composer experiment:metrics -- --phase baseline --diff-ref experiment-baseline-v1
```

**Step 1-2.** baseline を GitHub に push し、draft PR を作成して CI 緑を確認する。

**この Step の目的:** exp ブランチへの push だけでは CI が走らない（push トリガーは `main`/`master` のみ）。フェーズ別の CI 結果を GitHub 上に残すため、この時点で draft PR を1本作り、以降の各 push を同じ PR に積む。ブランチはタグと同一で差分ゼロのため、`gh pr create` を成立させる anchor として空コミットを1つ積む（app ファイル差分を増やさないので `git_app` メトリクスに影響しない）。

```bash
git commit --allow-empty -m "chore(exp): baseline anchor for api-spec-change-status-int"
git push -u origin exp/api-spec-change-status-int
gh pr create --draft --base main --head exp/api-spec-change-status-int \
  --title "exp: api-spec-change-status-int（improved）" \
  --body "$(cat <<'EOF'
## Summary
- タスク `status` を string から integer（0/1/2）へ変更する実験
- improved 構成（TaskService / TaskRepository に集約）
- 静的フロント（`public/app/tasks.html` + `tasks.js`）を int 仕様に追従

## Test plan（フェーズ別 CI）
- [ ] baseline コミットで CI 4 ジョブ緑
- [ ] after_update コミットで CI 赤（テスト未修正・意図的）
- [ ] after_fix コミットで CI 4 ジョブすべて成功
- [ ] `experiment/results/api-spec-change-status-int/` に 3 フェーズ JSON + RECORD.md がある

実験用 PR。マージはしない。
EOF
)"
```

GitHub Actions（4 ジョブ）が緑になることを確認し、失敗0を RECORD.md の baseline 行に記録する。

```bash
gh pr checks exp/api-spec-change-status-int --watch
```

---

### Phase 2: 変更適用（テスト・Postman 未着手）

**この Phase の目的:** 仕様変更を本番コードに適用し、テスト未修正の失敗状態（after_update）を計測できるようにする。

**Step 2-1.** マイグレーションファイルを生成する。

```bash
docker compose exec app php artisan make:migration change_status_to_integer_on_tasks_table
```

**Step 2-2.** 生成されたマイグレーションを編集する。

- **ファイル:** `database/migrations/*_change_status_to_integer_on_tasks_table.php`（Step 2-1 で生成されたパス）
- **場所:** `up()` / `down()` メソッド全体
- **解説:** PostgreSQL 専用 SQL で既存 string 値を int に移行し、カラム型を smallint に変更する。
- **変更前:** （空の `up()` / `down()` スタブ）
- **変更後:**

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
  public function up(): void
  {
    DB::statement("
      ALTER TABLE tasks
      ALTER COLUMN status TYPE smallint
      USING (
        CASE status
          WHEN 'todo' THEN 0
          WHEN 'in_progress' THEN 1
          WHEN 'done' THEN 2
          ELSE 0
        END
      )
    ");
  }

  public function down(): void
  {
    DB::statement("
      ALTER TABLE tasks
      ALTER COLUMN status TYPE varchar(255)
      USING (
        CASE status
          WHEN 0 THEN 'todo'
          WHEN 1 THEN 'in_progress'
          WHEN 2 THEN 'done'
          ELSE 'todo'
        END
      )
    ");
  }
};
```

**Step 2-3.** マイグレーションを適用する。

```bash
docker compose exec app php artisan migrate
```

**Step 2-4.** config の status 定義を int ベースに変更する。

- **ファイル:** `config/task.php`
- **場所:** 5行目 `status_values`
- **解説:** 全層が参照する status の許可値と表示ラベルを int ベースで定義する。
- **変更前:**

```php
  'status_values' => ['todo', 'in_progress', 'done'],
```

- **変更後:**

```php
  'status_values' => [0, 1, 2],
  'status_labels' => [
    0 => 'todo',
    1 => 'in_progress',
    2 => 'done',
  ],
```

**Step 2-5.** Model に integer cast と PHPDoc を追加する。

- **ファイル:** `app/Models/Task.php`
- **場所:** PHPDoc 15行目、`casts()` 21–26行目
- **解説:** Eloquent が DB の smallint を PHP int として扱い、JSON 出力も int になるようにする。
- **変更前:**

```php
 * @property string $status
```

```php
  protected function casts(): array
  {
    return [
      'due_date' => 'date',
    ];
  }
```

- **変更後:**

```php
 * @property int $status
```

```php
  protected function casts(): array
  {
    return [
      'status' => 'integer',
      'due_date' => 'date',
    ];
  }
```

**Step 2-6.** StoreTaskRequest の status バリデーションを integer に変更する。

- **ファイル:** `app/Http/Requests/StoreTaskRequest.php`
- **場所:** `rules()` 29行目
- **解説:** POST リクエストの status を int として受け付ける HTTP 境界にする。
- **変更前:**

```php
      'status' => ['required', 'string', Rule::in(config('task.status_values'))],
```

- **変更後:**

```php
      'status' => ['required', 'integer', Rule::in(config('task.status_values'))],
```

**Step 2-7.** UpdateTaskRequest の status バリデーションを integer に変更する。

- **ファイル:** `app/Http/Requests/UpdateTaskRequest.php`
- **場所:** `rules()` 29行目
- **解説:** PUT リクエストの status を int として受け付ける HTTP 境界にする。
- **変更前:**

```php
      'status' => ['sometimes', 'required', 'string', Rule::in(config('task.status_values'))],
```

- **変更後:**

```php
      'status' => ['sometimes', 'required', 'integer', Rule::in(config('task.status_values'))],
```

**Step 2-8.** IndexTaskRequest の status フィルタバリデーションを integer に変更する。

- **ファイル:** `app/Http/Requests/IndexTaskRequest.php`
- **場所:** `rules()` 43行目
- **解説:** 一覧クエリ `?status=` を int として検証する HTTP 境界にする。
- **変更前:**

```php
      'status' => ['nullable', 'string', Rule::in(config('task.status_values'))],
```

- **変更後:**

```php
      'status' => ['nullable', 'integer', Rule::in(config('task.status_values'))],
```

**Step 2-9.** TaskService の normalizeListFilters を int 正規化に変更する。

- **ファイル:** `app/Services/TaskService.php`
- **場所:** `normalizeListFilters()` 74–92行目
- **解説:** Controller を触らず、一覧フィルタの status を許可された int に正規化して Repository に渡す。
- **変更前:**

```php
   * @return array{title?: string, status?: string, due_date_sort?: string}
   */
  private function normalizeListFilters(array $query): array
  {
    $filters = [];

    if (isset($query['title']) && is_string($query['title'])) {
      $title = trim($query['title']);
      if ($title !== '') {
        $filters['title'] = $title;
      }
    }

    if (isset($query['status']) && is_string($query['status'])) {
      $status = trim($query['status']);
      if ($status !== '') {
        $filters['status'] = $status;
      }
    }
```

- **変更後:**

```php
   * @return array{title?: string, status?: int, due_date_sort?: string}
   */
  private function normalizeListFilters(array $query): array
  {
    $filters = [];

    if (isset($query['title']) && is_string($query['title'])) {
      $title = trim($query['title']);
      if ($title !== '') {
        $filters['title'] = $title;
      }
    }

    if (isset($query['status']) && is_numeric($query['status'])) {
      $status = (int) $query['status'];
      if (in_array($status, config('task.status_values'), true)) {
        $filters['status'] = $status;
      }
    }
```

**Step 2-10.** TaskService の normalizeTaskPayload に status の int キャストを追加する。

- **ファイル:** `app/Services/TaskService.php`
- **場所:** `normalizeTaskPayload()` `return $data;` の直前（126行前）
- **解説:** 作成・更新ペイロードの status を永続化前に int に揃える。
- **変更前:**

```php
    }

    return $data;
  }
}
```

- **変更後:**

```php
    }

    if (array_key_exists('status', $data)) {
      $data['status'] = (int) $data['status'];
    }

    return $data;
  }
}
```

**Step 2-11.** TaskRepository の status フィルタ比較を is_int に変更する。

- **ファイル:** `app/Repositories/TaskRepository.php`
- **場所:** `getFiltered()` 20–23行目
- **解説:** 正規化済み int フィルタで DB クエリを組み立てる。
- **変更前:**

```php
    $status = $filters['status'] ?? null;
    if (is_string($status) && $status !== '') {
      $query->where('status', $status);
    }
```

- **変更後:**

```php
    $status = $filters['status'] ?? null;
    if (is_int($status)) {
      $query->where('status', $status);
    }
```

**Step 2-12.** TaskRepositoryInterface の PHPDoc を更新する。

- **ファイル:** `app/Repositories/Contracts/TaskRepositoryInterface.php`
- **場所:** PHPDoc 11行目
- **解説:** インターフェースのフィルタ型注釈を実装と一致させる（メソッドシグネチャは変更しない）。
- **変更前:**

```php
   * @param  array{title?: string, status?: string, due_date_sort?: string}  $filters
```

- **変更後:**

```php
   * @param  array{title?: string, status?: int, due_date_sort?: string}  $filters
```

**Step 2-13.** HTML のフィルタ・モーダルの status セレクトを int value + ラベル表示に変更する。

- **ファイル:** `public/app/tasks.html`
- **場所:** フィルタ select 44–49行目、モーダル select 100–104行目
- **解説:** 静的 HTML には `config()` が使えないため、option の value を int にラベルを文字列に直接書き換える。送信値を int にしつつ、ユーザーには文字ラベルを表示する。
- **変更前:**

```html
          <select id="filter-status" name="status" class="app-input">
            <option value="">すべて</option>
            <option value="todo">todo</option>
            <option value="in_progress">in_progress</option>
            <option value="done">done</option>
          </select>
```

```html
          <select id="task-status" required class="app-input">
            <option value="todo">todo</option>
            <option value="in_progress">in_progress</option>
            <option value="done">done</option>
          </select>
```

- **変更後:**

```html
          <select id="filter-status" name="status" class="app-input">
            <option value="">すべて</option>
            <option value="0">todo</option>
            <option value="1">in_progress</option>
            <option value="2">done</option>
          </select>
```

```html
          <select id="task-status" required class="app-input">
            <option value="0">todo</option>
            <option value="1">in_progress</option>
            <option value="2">done</option>
          </select>
```

**Step 2-14.** JS の status 表示・既定値・送信値を int 仕様に合わせる。

- **ファイル:** `public/app/tasks.js`
- **場所:** `STATUS_LABELS` 追加、`renderTasks()` 106行目、`openCreateModal()` 136行目、`saveTask()` 164行目
- **解説:** API が返す status は int になるため、一覧表示は int→ラベルのマップで人間可読にする。作成モーダルの既定値を int の文字列にし、保存時は select 値を `Number()` で int に変換して送る。`openEditModal()` の `.value = task.status` は int を渡しても option の value と一致するため変更しない。
- **変更前:**

```js
  // ─── Task list ─────────────────────────────────────
  var currentTasks = [];
```

```js
        + '<td>' + escapeHtml(task.status) + '</td>'
```

```js
    document.getElementById('task-status').value = 'todo';
```

```js
      status: document.getElementById('task-status').value,
```

- **変更後:**

```js
  // ─── Task list ─────────────────────────────────────
  var STATUS_LABELS = { 0: 'todo', 1: 'in_progress', 2: 'done' };
  var currentTasks = [];
```

```js
        + '<td>' + escapeHtml(STATUS_LABELS[task.status] || task.status) + '</td>'
```

```js
    document.getElementById('task-status').value = '0';
```

```js
      status: Number(document.getElementById('task-status').value),
```

**Step 2-15.** 静的フロントはビルド不要のため、`public/app/` の変更はそのまま nginx が配信する（`composer npm:docker-build` は Breeze 認証画面用の Vite 資産のみで、本シナリオでは実行不要）。

---

### Phase 3: after_update メトリクス

**この Phase の目的:** テスト未修正のまま、どれだけ壊れたかを数値化する。

**Step 3-1.** 変更をコミットする。

```bash
git add database/ config/ app/ public/
git commit -m "$(cat <<'EOF'
feat: change task status from string to integer
Migration, config, model, requests, TaskService, TaskRepository, and HTML/JS front.
Tests and Postman are intentionally unchanged for after_update measurement.
EOF
)"
```

**Step 3-2.** after_update フェーズのメトリクスを取得する（PHPUnit / Newman の失敗数を記録）。

```bash
composer experiment:metrics -- --phase after_update --diff-ref experiment-baseline-v1
```

**Step 3-3.** after_update コミットを push し、CI が赤くなることを確認・記録する。

**この Step の目的:** テスト未修正の壊れた状態を GitHub Actions 上でも赤として残す。`php-tests`（PHPUnit）と `api-tests`（Newman）が失敗し、依存側でフォーマット/型/lint が崩れていれば `php-quality`・`frontend` も赤になる。失敗ジョブ数を RECORD.md の after_update 行に記録する。

```bash
git push origin exp/api-spec-change-status-int
gh pr checks exp/api-spec-change-status-int --watch
```

> **注意:** `ci.yml` は `concurrency: cancel-in-progress` のため、赤の run が完了する前に次の push（Phase 5）を行うとキャンセルされる。`--watch` で CI 完了を待ってから Phase 4 の修正に進む。

---

### Phase 4: テスト・Postman 修正 → CI 緑

**この Phase の目的:** 仕様変更に合わせてテストと Postman を直し、修正工数（after_fix）を計測可能にする。

**Step 4-1.** TaskApiTest の status 期待値を int に書き換える。

- **ファイル:** `tests/Feature/TaskApiTest.php`
- **場所:** ファイル全体の `status` 参照
- **解説:** API Feature テストが新しい int status 仕様と一致するようにする。
- **変更前（代表箇所）:**

```php
      'status' => 'todo',
```

```php
      'status' => 'in_progress',
```

```php
      'status' => 'invalid',
```

- **変更後（代表箇所）:**

```php
      'status' => 0,
```

```php
      'status' => 1,
```

```php
      'status' => 'invalid',  // 422 テストは文字列のまま（バリデーションエラー確認用）
```

全置換対応表:

| 変更前 | 変更後 |
| --- | --- |
| `'status' => 'todo'` | `'status' => 0` |
| `'status' => 'in_progress'` | `'status' => 1` |
| `'status' => 'done'` | `'status' => 2` |

**Step 4-2.** TaskListFilterTest の status フィルタと seed データを int に書き換える。

- **ファイル:** `tests/Feature/TaskListFilterTest.php`
- **場所:** 42行目（フィルタクエリ）、73–95行目（seed）
- **解説:** フィルタクエリとシードデータを int status に合わせ、`done` 相当は `2` で検証する。S1 では一覧フィルタは API のみのため Web 側クエリは存在しない。
- **変更前:**

```php
    $response = $this->actingAs($this->user)->getJson('/api/tasks?status=done');
```

```php
      'status' => 'todo',
```

```php
      'status' => 'done',
```

```php
      'status' => 'in_progress',
```

- **変更後:**

```php
    $response = $this->actingAs($this->user)->getJson('/api/tasks?status=2');
```

```php
      'status' => 0,
```

```php
      'status' => 2,
```

```php
      'status' => 1,
```

**Step 4-3.** Postman コレクションの request body を int status に更新する。

- **ファイル:** `postman/Task-API.postman_collection.json`
- **場所:** 195行目、255行目（`raw` body）
- **解説:** Newman が POST/PUT で int status を送り、新 API 仕様で通るようにする。422 テスト（226行目）は `"invalid"` のまま。
- **変更前:**

```json
"raw": "{\n  \"title\": \"Postman task\",\n  \"status\": \"todo\"\n}"
```

```json
"raw": "{\n  \"title\": \"Updated from Postman\",\n  \"status\": \"in_progress\"\n}"
```

- **変更後:**

```json
"raw": "{\n  \"title\": \"Postman task\",\n  \"status\": 0\n}"
```

```json
"raw": "{\n  \"title\": \"Updated from Postman\",\n  \"status\": 1\n}"
```

**Step 4-4.** CI 相当の品質チェックを実行し、すべて緑にする。

```bash
./scripts/check-quality.sh
```

---

### Phase 5: after_fix メトリクス・記録

**Step 5-1.** 変更をコミットする。

```bash
git add tests/ postman/
git commit -m "$(cat <<'EOF'
test: update tests and Postman for status integer

Align Feature tests and Newman collection with 0/1/2 status values.
EOF
)"
```

**Step 5-2.** after_fix フェーズのメトリクスを取得する。

```bash
composer experiment:metrics -- --phase after_fix --diff-ref experiment-baseline-v1
```

**Step 5-3.** 実験記録を生成する。

```bash
composer experiment:record -- --scenario api-spec-change-status-int --write
```

**Step 5-4.** 結果を experiment/results/ に公開する。

```bash
./scripts/publish-experiment-results.sh --scenario api-spec-change-status-int
```

**Step 5-5.** 手動項目を追加する。

**Step 5-6.** 結果をコミット・プッシュする（upstream は Phase 1 で設定済み）。この push が after_fix の CI（緑）を発火する。

```bash
git add experiment/results/api-spec-change-status-int/
git commit -m "docs(experiment): publish api-spec-change-status-int results"
git push origin exp/api-spec-change-status-int
```

**Step 5-7.** after_fix の CI 緑を確認する（PR は Phase 1 Step 1-2 で作成済みのため新規作成しない）。

```bash
gh pr checks exp/api-spec-change-status-int --watch
gh pr ready exp/api-spec-change-status-int   # 任意: draft を Ready に切り替え
```

GitHub Actions 4 ジョブすべて成功を確認し、失敗0を RECORD.md の after_fix 行に記録する。

**Step 5-8.** 結果を公開ディレクトリにコピーする。

```bash
./scripts/publish-experiment-results.sh --scenario api-spec-change-status-int
```

**Step 5-9.** 結果を手動で変更し、コミット・プッシュする。

```bash
git add experiment/results/api-spec-change-status-int/RECORD.md
git commit -m "$(cat <<'EOF'
docs: fill manual experiment record for api-spec-change-status-int

Add CI, work time, commits, and notes to the manual recording table.
EOF
)"
git push origin exp/api-spec-change-status-int
```

---

## 5. 完了条件

- [ ]  after_fix で GitHub Actions 4 ジョブすべて成功（`./scripts/check-quality.sh` がローカルで緑）
- [ ]  各フェーズの GitHub CI を同一 PR に記録済み（baseline 緑 / after_update 赤 / after_fix 緑）
- [ ]  `baseline` / `after_update` / `after_fix` の 3 フェーズ JSON が `experiment/metrics/` に存在する
- [ ]  `experiment/results/` に結果がコピーされている（`publish-experiment-results.sh` 実行済み）
- [ ]  対照スタック（S0 Blade: `tech-update-task-app`）で同一手順を実施済み（第2章 スタック比較）

## 6. 触らないファイルとその理由

| ファイル | 理由 |
| --- | --- |
| `app/Http/Controllers/API/TaskController.php` | improved 構成では Controller は HTTP 受け渡しのみとし、正規化は TaskService に集約する実験設計のため。S0（Blade）との差（Controller 内修正の有無）を計測する対照群でもある |
| `app/Http/Resources/TaskResource.php` | Model の `integer` cast により JSON 出力の `status` も自動的に int になるため変更不要 |
| `database/migrations/2026_05_12_052659_create_tasks_table.php` | 既存マイグレーションは変更せず、新規マイグレーションで型変更・データ移行を行うため |

## 関連

- [EXPERIMENT.md](../../EXPERIMENT.md) — 実験設計・主評価指標の定義
- [EXPERIMENT.md — メトリクス記録テンプレート](../EXPERIMENT.md#メトリクス記録テンプレート) — スプレッドシート列定義
- [api-spec-change-priority.md](./api-spec-change-priority.md) — 属性追加シナリオ（対比用）
- [db-schema-change.md](./db-schema-change.md) — クエリ変更シナリオ
