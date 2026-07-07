# シナリオ: API 仕様変更 — 属性追加（`api-spec-change-priority`）

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

タスク REST API と Web UI に新属性 `priority`（`low` / `medium` / `high`、デフォルト `medium`）を追加する実験です。既存クライアントが `priority` を送らなくても動作する**非破壊的な属性追加**であり、legacy 構成（Controller 内に正規化・一覧クエリあり）と比べて修正が何ファイルに分散するかを測ります。**完全版**では CRUD に加え、一覧の**表示・フィルタ（`?priority=`）・並び替え（`?priority_sort=asc|desc`）**まで legacy と parity を取ります。improved では属性の正規化は `TaskService::normalizeTaskPayload`、一覧クエリは `IndexTaskRequest` → `normalizeListFilters` → `TaskRepository::getFiltered` に集約され、legacy との差は主に **Controller 2 ファイル（一覧クエリ + normalizeTaskPayload）** として `git_app.files_changed` に現れます。

---

## 1. 概要

| 項目 | 値 |
| --- | --- |
| リポジトリ | improved |
| 実験の内容 | API 仕様変更 — priority 属性追加（CRUD + 一覧列 + フィルタ + 並び替え） |
| ブランチ名 | `exp/api-spec-change-priority` |
| 参照MD | `docs/scenarios/api-spec-change-priority.md` |
| 一覧クエリパラメータ | `priority`（フィルタ）, `priority_sort`（`asc` / `desc`、デフォルト `asc` = low → medium → high） |

---

## 2. 事前条件チェック

- [ ]  `experiment-baseline-v1` または CI 緑 — ベースラインは 4 属性のみで比較の起点になる
- [ ]  Docker 起動 — migrate / PHPUnit / Newman / `check-quality.sh` がコンテナ前提のため
- [ ]  PostgreSQL（status 数値化・タイトル検索のみ） — 本シナリオの migration は標準 `Schema::table` で足りる

---

## 3. 修正対象ファイル一覧

| # | ファイルパス | 修正箇所 | フェーズ | 作業内容 | 解説 |
| --- | --- | --- | --- | --- | --- |
| 1 | `database/migrations/*_add_priority_to_tasks_table.php` | `up()` / `down()` | 2 | カラム追加 | DB 永続化 |
| 2 | `config/task.php` | 配列末尾 | 2 | `priority_values` | バリデーション・UI 共有 |
| 3 | `app/Models/Task.php` | PHPDoc / Fillable | 2 | `priority` 追加 | mass assignment |
| 4 | `app/Http/Resources/TaskResource.php` | `toArray()` | 2 | JSON に `priority` | API 契約 |
| 5 | `app/Http/Requests/StoreTaskRequest.php` | `rules()` | 2 | バリデーション | 作成時検証 |
| 6 | `app/Http/Requests/UpdateTaskRequest.php` | `rules()` | 2 | バリデーション | 更新時検証 |
| 7 | `app/Services/TaskService.php` | `normalizeTaskPayload()` | 2 | 許可リスト | CRUD 正規化 |
| 8 | `app/Services/TaskService.php` | `normalizeListFilters()` | 2 | フィルタ/ソート | 一覧正規化 |
| 9 | `app/Http/Requests/IndexTaskRequest.php` | `prepareForValidation` / `rules()` | 2 | `priority` / `priority_sort` | 一覧入力検証 |
| 10 | `app/Repositories/TaskRepository.php` | `getFiltered()` | 2 | WHERE + ORDER BY | クエリ実行 |
| 11 | `app/Repositories/Contracts/TaskRepositoryInterface.php` | PHPDoc | 2 | filters 型 | Interface 整合 |
| 12 | `resources/views/tasks/_form.blade.php` | status と due_date の間 | 2 | select 追加 | 作成・編集 |
| 13 | `resources/views/tasks/index.blade.php` | フィルタ + テーブル | 2 | 列・フィルタ・ソート UI | Web 一覧完全対応 |
| 14 | `app/Http/Controllers/Web/TaskController.php` | `update()` 行 50–52 | 2 | redirect query | 更新後フィルタ状態維持 |
| 15 | `tests/Feature/TaskApiTest.php` | 各メソッド | 4 | CRUD 期待値 | API 契約 |
| 16 | `tests/Feature/TaskWebTest.php` | index / store / update | 4 | 表示・DB | Web CRUD |
| 17 | `tests/Feature/TaskListFilterTest.php` | seed + 新規 4 テスト | 4 | フィルタ/ソート | 一覧クエリ |
| 18 | `postman/Task-API.postman_collection.json` | POST / PUT tests | 4 | アサーション | Newman |

---

## 4. 実施手順

### Phase 0: ブランチ作成

**この Phase の目的:** ベースラインから実験ブランチを切り、diff 計測の起点を固定する。

**Step 0-1.** 実験ブランチを作成する。

```bash
git checkout -b exp/api-spec-change-priority experiment-baseline-v1
```

---

### Phase 1: baseline メトリクス

**この Phase の目的:** 変更前の状態を記録する。

**Step 1-1.** baseline フェーズのメトリクスを取得する。

```bash
composer experiment:metrics -- --phase baseline --diff-ref experiment-baseline-v1
```

**Step 1-2.** baseline を GitHub に push し、draft PR を作成して CI 緑を確認する。

**この Step の目的:** exp ブランチへの push だけでは CI が走らない（push トリガーは `main`/`master` のみ）。フェーズ別の CI 結果を GitHub 上に残すため、この時点で draft PR を1本作り、以降の各 push を同じ PR に積む。ブランチはタグと同一で差分ゼロのため、`gh pr create` を成立させる anchor として空コミットを1つ積む（app ファイル差分を増やさないので `git_app` メトリクスに影響しない）。

```bash
git commit --allow-empty -m "chore(exp): baseline anchor for api-spec-change-priority"
git push -u origin exp/api-spec-change-priority
gh pr create --draft --base main --head exp/api-spec-change-priority \
  --title "exp: api-spec-change-priority" \
  --body "$(cat <<'EOF'
実験用 PR。マージはしない。

## Test plan（フェーズ別 CI）
- [ ] baseline コミットで CI 4 ジョブ緑
- [ ] after_update コミットで CI 赤（テスト未修正・意図的）
- [ ] after_fix コミットで CI 4 ジョブすべて成功
EOF
)"
gh pr checks exp/api-spec-change-priority --watch
```

GitHub Actions（4 ジョブ）が緑になることを確認し、失敗0を RECORD.md の baseline 行に記録する。

---

### Phase 2: 変更適用（テスト・Postman 未着手）

**この Phase の目的:** 本番コードに完全版 priority を適用し、after_update を計測できる状態にする。

**Step 2-1.** マイグレーションファイルを生成する。

```bash
docker compose exec app php artisan make:migration add_priority_to_tasks_table
```

**Step 2-2.** マイグレーション編集

- **ファイル:** `database/migrations/YYYY_MM_DD_HHMMSS_add_priority_to_tasks_table.php`
- **場所:** `up()` / `down()`
- **解説:** 未指定時 DB デフォルト `medium` を設定する。
- **変更前:**

```php
public function up(): void
{
    //
}

public function down(): void
{
    //
}
```

- **変更後:**

```php
public function up(): void
{
    Schema::table('tasks', function (Blueprint $table) {
        $table->string('priority')->default('medium');
    });
}

public function down(): void
{
    Schema::table('tasks', function (Blueprint $table) {
        $table->dropColumn('priority');
    });
}
```

**Step 2-3.** マイグレーションを実行する。

```bash
docker compose exec app php artisan migrate
```

**Step 2-4.** `config/task.php`

- **解説:** FormRequest / Blade が同じ許可値を参照する。
- **変更前:**

```php
return [
  'default_user_email' => env('DEFAULT_TASK_USER_EMAIL', 'test@example.com'),
  'status_values' => ['todo', 'in_progress', 'done'],
];
```

- **変更後:**

```php
return [
  'default_user_email' => env('DEFAULT_TASK_USER_EMAIL', 'test@example.com'),
  'status_values' => ['todo', 'in_progress', 'done'],
  'priority_values' => ['low', 'medium', 'high'],
];
```

**Step 2-5.** `app/Models/Task.php`

- **解説:** `fill()` で `priority` が保存されるようにする。
- **変更前:**

```php
/**
 * @property int $id
 * @property int $user_id
 * @property string $title
 * @property string|null $description
 * @property string $status
 * @property Carbon|null $due_date
 */
#[Fillable(['user_id', 'title', 'description', 'status', 'due_date'])]
```

- **変更後:**

```php
/**
 * @property int $id
 * @property int $user_id
 * @property string $title
 * @property string|null $description
 * @property string $status
 * @property string $priority
 * @property Carbon|null $due_date
 */
#[Fillable(['user_id', 'title', 'description', 'status', 'priority', 'due_date'])]
```

**Step 2-6.** `app/Http/Resources/TaskResource.php` — `toArray()` 行 21–27

- **解説:** API レスポンスに `priority` を含める。
- **変更前:**

```php
return [
  'id' => $this->id,
  'title' => $this->title,
  'status' => $this->status,
  'due_date' => $this->due_date?->format('Y-m-d'),
  'description' => $this->description,
];
```

- **変更後:**

```php
return [
  'id' => $this->id,
  'title' => $this->title,
  'status' => $this->status,
  'priority' => $this->priority,
  'due_date' => $this->due_date?->format('Y-m-d'),
  'description' => $this->description,
];
```

**Step 2-7.** `app/Http/Requests/StoreTaskRequest.php` — `rules()` 行 26–31

- **解説:** 省略時は DB デフォルト、送信時のみ検証。
- **変更後（rules 全体）:**

```php
return [
  'title' => ['required', 'string', 'max:255'],
  'description' => ['nullable', 'string'],
  'status' => ['required', 'string', Rule::in(config('task.status_values'))],
  'priority' => ['nullable', 'string', Rule::in(config('task.priority_values'))],
  'due_date' => ['nullable', 'date'],
];
```

**Step 2-8.** `app/Http/Requests/UpdateTaskRequest.php` — `rules()` 行 26–31

- **変更後（rules 全体）:**

```php
return [
  'title' => ['sometimes', 'required', 'string', 'max:255'],
  'description' => ['sometimes', 'nullable', 'string'],
  'status' => ['sometimes', 'required', 'string', Rule::in(config('task.status_values'))],
  'priority' => ['sometimes', 'nullable', 'string', Rule::in(config('task.priority_values'))],
  'due_date' => ['sometimes', 'nullable', 'date'],
];
```

**Step 2-9.** `app/Services/TaskService.php` — `normalizeTaskPayload()` 行 107–110

- **解説:** CRUD 用正規化で `priority` を通す。
- **変更前:**

```php
$allowed = ['title', 'description', 'status', 'due_date'];
$data = array_intersect_key($data, array_flip($allowed));
```

- **変更後:**

```php
$allowed = ['title', 'description', 'status', 'priority', 'due_date'];
$data = array_intersect_key($data, array_flip($allowed));
```

**Step 2-10.** `app/Services/TaskService.php` — `normalizeListFilters()` 行 72–100

- **解説:** 一覧クエリ用に `priority` フィルタと `priority_sort` を正規化する。
- **変更前（PHPDoc + メソッド）:**

```php
  /**
   * @param  array<string, mixed>  $query
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

    if (isset($query['due_date_sort']) && $query['due_date_sort'] === 'desc') {
      $filters['due_date_sort'] = 'desc';
    } elseif (isset($query['due_date_sort']) && $query['due_date_sort'] === 'asc') {
      $filters['due_date_sort'] = 'asc';
    }

    return $filters;
  }
```

- **変更後:**

```php
  /**
   * @param  array<string, mixed>  $query
   * @return array{title?: string, status?: string, priority?: string, priority_sort?: string, due_date_sort?: string}
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

    if (isset($query['priority']) && is_string($query['priority'])) {
      $priority = trim($query['priority']);
      if ($priority !== '') {
        $filters['priority'] = $priority;
      }
    }

    if (isset($query['priority_sort']) && $query['priority_sort'] === 'desc') {
      $filters['priority_sort'] = 'desc';
    } elseif (isset($query['priority_sort']) && $query['priority_sort'] === 'asc') {
      $filters['priority_sort'] = 'asc';
    }

    if (isset($query['due_date_sort']) && $query['due_date_sort'] === 'desc') {
      $filters['due_date_sort'] = 'desc';
    } elseif (isset($query['due_date_sort']) && $query['due_date_sort'] === 'asc') {
      $filters['due_date_sort'] = 'asc';
    }

    return $filters;
  }
```

**Step 2-11.** `app/Http/Requests/IndexTaskRequest.php`

- **解説:** Web/API 共通の一覧入力検証。空文字は null に正規化。
- **変更前 `prepareForValidation`:**

```php
    foreach (['title', 'status', 'due_date_sort'] as $key) {
```

- **変更後 `prepareForValidation`:**

```php
    foreach (['title', 'status', 'priority', 'priority_sort', 'due_date_sort'] as $key) {
```

- **変更前 `rules()`:**

```php
    return [
      'title' => ['nullable', 'string', 'max:255'],
      'status' => ['nullable', 'string', Rule::in(config('task.status_values'))],
      'due_date_sort' => ['nullable', 'string', Rule::in(['asc', 'desc'])],
    ];
```

- **変更後 `rules()`:**

```php
    return [
      'title' => ['nullable', 'string', 'max:255'],
      'status' => ['nullable', 'string', Rule::in(config('task.status_values'))],
      'priority' => ['nullable', 'string', Rule::in(config('task.priority_values'))],
      'priority_sort' => ['nullable', 'string', Rule::in(['asc', 'desc'])],
      'due_date_sort' => ['nullable', 'string', Rule::in(['asc', 'desc'])],
    ];
```

**Step 2-12.** `app/Repositories/TaskRepository.php` — `getFiltered()` 行 11–30

- **解説:** 辞書順ではなく `CASE` で low → medium → high をソート。優先度の後に既存の期限ソートを適用。
- **変更前:**

```php
  public function getFiltered(int $userId, array $filters = []): Collection
  {
    $query = Task::query()->where('user_id', $userId);

    $title = $filters['title'] ?? null;
    if (is_string($title) && $title !== '') {
      $query->where('title', 'like', '%'.$this->escapeLike($title).'%');
    }

    $status = $filters['status'] ?? null;
    if (is_string($status) && $status !== '') {
      $query->where('status', $status);
    }

    $dueSort = $filters['due_date_sort'] ?? 'asc';
    $direction = $dueSort === 'desc' ? 'desc' : 'asc';
    $query->orderByRaw('due_date IS NULL DESC')->orderBy('due_date', $direction)->orderBy('id');

    /** @var Collection<int, Task> */
    return $query->get();
  }
```

- **変更後:**

```php
  public function getFiltered(int $userId, array $filters = []): Collection
  {
    $query = Task::query()->where('user_id', $userId);

    $title = $filters['title'] ?? null;
    if (is_string($title) && $title !== '') {
      $query->where('title', 'like', '%'.$this->escapeLike($title).'%');
    }

    $status = $filters['status'] ?? null;
    if (is_string($status) && $status !== '') {
      $query->where('status', $status);
    }

    $priority = $filters['priority'] ?? null;
    if (is_string($priority) && $priority !== '') {
      $query->where('priority', $priority);
    }

    $prioritySort = $filters['priority_sort'] ?? 'asc';
    $priorityDirection = $prioritySort === 'desc' ? 'desc' : 'asc';
    $query->orderByRaw(
      "CASE priority WHEN 'low' THEN 1 WHEN 'medium' THEN 2 WHEN 'high' THEN 3 ELSE 4 END {$priorityDirection}"
    );

    $dueSort = $filters['due_date_sort'] ?? 'asc';
    $direction = $dueSort === 'desc' ? 'desc' : 'asc';
    $query->orderByRaw('due_date IS NULL DESC')->orderBy('due_date', $direction)->orderBy('id');

    /** @var Collection<int, Task> */
    return $query->get();
  }
```

**Step 2-13.** `app/Repositories/Contracts/TaskRepositoryInterface.php` — PHPDoc 行 10–14

- **変更前:**

```php
  /**
   * @param  array{title?: string, status?: string, due_date_sort?: string}  $filters
   * @return Collection<int, Task>
   */
```

- **変更後:**

```php
  /**
   * @param  array{title?: string, status?: string, priority?: string, priority_sort?: string, due_date_sort?: string}  $filters
   * @return Collection<int, Task>
   */
```

**Step 2-14.** `resources/views/tasks/_form.blade.php` — status の直後

- **解説:** 作成・編集フォームから priority を送る。
- **追加ブロック（status と due_date の間に挿入）:**

```php
    <div class="app-form-field">
        <x-input-label for="priority" value="優先度" />
        <x-select-input id="priority" name="priority" class="block w-full">
            @foreach (config('task.priority_values') as $priority)
                <option value="{{ $priority }}" @selected(old('priority', $task?->priority ?? 'medium') === $priority)>
                    {{ $priority }}
                </option>
            @endforeach
        </x-select-input>
        <x-input-error :messages="$errors->get('priority')" class="mt-2" />
    </div>
```

**Step 2-15.** `resources/views/tasks/index.blade.php`

- **解説:** フィルタ・並び替え UI とテーブル列を追加。`status` フィルタの直後に priority フィルタと priority 並び替えを挿入し、テーブルに優先度列を追加する。
- **追加（status フィルタ `<div>` の直後、`期限並び替え` の前）:**

```php
                <div class="app-form-field mb-0 min-w-[8rem] flex-1">
                    <x-input-label for="filter-priority" value="優先度" />
                    <x-select-input id="filter-priority" name="priority" class="block w-full">
                        <option value="">すべて</option>
                        @foreach (config('task.priority_values') as $priority)
                            <option value="{{ $priority }}" @selected(old('priority', request('priority')) === $priority)>
                                {{ $priority }}
                            </option>
                        @endforeach
                    </x-select-input>
                    <x-input-error :messages="$errors->get('priority')" class="mt-1" />
                </div>

                <div class="app-form-field mb-0 min-w-[10rem] flex-1">
                    <x-input-label value="優先度並び替え" />
                    <div class="app-radio-group">
                        <label class="app-radio-label">
                            <input
                                type="radio"
                                name="priority_sort"
                                value="asc"
                                class="app-radio"
                                @checked(old('priority_sort', request('priority_sort', 'asc')) === 'asc')
                            >
                            昇順
                        </label>
                        <label class="app-radio-label">
                            <input
                                type="radio"
                                name="priority_sort"
                                value="desc"
                                class="app-radio"
                                @checked(old('priority_sort', request('priority_sort')) === 'desc')
                            >
                            降順
                        </label>
                    </div>
                    <x-input-error :messages="$errors->get('priority_sort')" class="mt-1" />
                </div>
```

- **thead 変更後:**

```php
                    <tr>
                        <th>タイトル</th>
                        <th>ステータス</th>
                        <th>優先度</th>
                        <th>期限</th>
                        <th class="text-right">操作</th>
                    </tr>
```

- **tbody 行 変更後:**

```php
                            <td class="font-medium text-gray-900">{{ $task->title }}</td>
                            <td>{{ $task->status }}</td>
                            <td>{{ $task->priority }}</td>
                            <td>{{ $task->due_date?->format('Y-m-d') ?? '-' }}</td>
```

- **empty 行:**

```php
                            <td colspan="5" class="py-8 text-center text-gray-500">タスクがありません</td>
```

**Step 2-16.** `app/Http/Controllers/Web/TaskController.php` — `update()` 行 50–52

- **解説:** タスク更新後も一覧フィルタ状態（priority 含む）を維持する。index / store / API index は変更不要。
- **変更前:**

```php
    return redirect()
      ->route('tasks.index', $request->only(['title', 'status', 'due_date_sort']))
      ->with('status', 'タスクを更新しました。');
```

- **変更後:**

```php
    return redirect()
      ->route('tasks.index', $request->only(['title', 'status', 'priority', 'priority_sort', 'due_date_sort']))
      ->with('status', 'タスクを更新しました。');
```

**Step 2-17.** フロントエンド資産をビルドする。

```bash
composer npm:docker-build
```

---

### Phase 3: after_update メトリクス

**この Phase の目的:** テスト未修正の中間状態を計測する。

**Step 3-1.**

```bash
git add -A
git commit -m "feat: add priority attribute with list filter and sort (tests not updated)"
```

**Step 3-2.**

```bash
composer experiment:metrics -- --phase after_update --diff-ref experiment-baseline-v1
```

> **補足:** 非破壊的 CRUD 変更のみなら fail 0 の可能性あり。`TaskListFilterTest` の seed に `priority` が無いと DB エラーになる場合は fail > 0。いずれも記録する。
> 

**Step 3-3.** after_update コミットを push し、CI 結果を確認・記録する。

**この Step の目的:** 更新直後の状態を GitHub Actions 上にも残す。本シナリオは非破壊的なため fail 0（CI 緑）のこともあれば、seed 不整合で `php-tests`・`api-tests` が赤になることもある。いずれの結果でも失敗ジョブ数を RECORD.md の after_update 行に記録する。

```bash
git push origin exp/api-spec-change-priority
gh pr checks exp/api-spec-change-priority --watch
```

> **注意:** `ci.yml` は `concurrency: cancel-in-progress` のため、run が完了する前に次の push（Phase 5）を行うとキャンセルされる。`--watch` で CI 完了を待ってから Phase 4 に進む。

---

### Phase 4: テスト・Postman 修正 → CI 緑

**この Phase の目的:** 完全版仕様を CI で固定し after_fix を計測可能にする。

**Step 4-1.** `tests/Feature/TaskApiTest.php`

- **解説:** CRUD の priority 契約を固定。
- **store テスト変更後:**

```php
    $response->assertCreated();
    $response->assertJsonPath('data.title', 'New Task');
    $response->assertJsonPath('data.priority', 'medium');
    $this->assertDatabaseHas('tasks', ['title' => 'New Task', 'priority' => 'medium']);
```

- **update テスト変更後:**

```php
    $response = $this->actingAs($this->user)->putJson("/api/tasks/{$task->id}", [
      'title' => 'Updated',
      'status' => 'in_progress',
      'priority' => 'high',
    ]);

    $response->assertOk();
    $response->assertJsonPath('data.title', 'Updated');
    $response->assertJsonPath('data.priority', 'high');
```

- **末尾に追加:**

```php
  /** POST priority 不正 → 422 */
  public function test_store_with_invalid_priority_returns_422(): void
  {
    $response = $this->actingAs($this->user)->postJson('/api/tasks', [
      'title' => 't',
      'status' => 'todo',
      'priority' => 'urgent',
    ]);

    $response->assertStatus(422);
    $response->assertJsonValidationErrors('priority');
  }
```

**Step 4-2.** `tests/Feature/TaskWebTest.php`

- **index テスト変更後:**

```php
    Task::query()->create([
      'user_id' => $this->user->id,
      'title' => 'Web task',
      'description' => null,
      'status' => 'todo',
      'priority' => 'high',
      'due_date' => null,
    ]);

    $response = $this->actingAs($this->user)->get('/tasks');

    $response->assertOk();
    $response->assertSee('Web task', false);
    $response->assertSee('high', false);
```

- **store テスト変更後:**

```php
    $response = $this->actingAs($this->user)->post('/tasks', [
      'title' => 'New web task',
      'status' => 'todo',
      'priority' => 'low',
    ]);

    $response->assertRedirect(route('tasks.index'));
    $this->assertDatabaseHas('tasks', [
      'user_id' => $this->user->id,
      'title' => 'New web task',
      'priority' => 'low',
    ]);
```

- **update テスト変更後:**

```php
    $response = $this->actingAs($this->user)->put("/tasks/{$task->id}", [
      'title' => 'After',
      'status' => 'in_progress',
      'priority' => 'high',
    ]);

    $response->assertRedirect(route('tasks.index', [
      'title' => 'After',
      'status' => 'in_progress',
      'priority' => 'high',
    ]));
    $this->assertDatabaseHas('tasks', [
      'id' => $task->id,
      'title' => 'After',
      'status' => 'in_progress',
      'priority' => 'high',
    ]);
```

**Step 4-3.** `tests/Feature/TaskListFilterTest.php`

- **解説:** 既存 seed は全件 `priority => 'medium'` にし既存 due_date テストを維持。priority 専用 seed でフィルタ/ソートを検証。
- **`seedTasks()` 各 create に追加:**

```php
      'priority' => 'medium',
```

- **ファイル末尾（`seedTasks()` の後）に private メソッド追加:**

```php
  private function seedTasksWithDistinctPriorities(): void
  {
    Task::query()->create([
      'user_id' => $this->user->id,
      'title' => 'Foo task',
      'description' => null,
      'status' => 'todo',
      'priority' => 'low',
      'due_date' => null,
    ]);

    Task::query()->create([
      'user_id' => $this->user->id,
      'title' => 'Bar task',
      'description' => null,
      'status' => 'done',
      'priority' => 'high',
      'due_date' => null,
    ]);

    Task::query()->create([
      'user_id' => $this->user->id,
      'title' => 'Baz task',
      'description' => null,
      'status' => 'in_progress',
      'priority' => 'medium',
      'due_date' => null,
    ]);
  }
```

- **新規テスト 4 本追加（`test_api_index_sorts_due_date_desc` の後）:**

```php
  public function test_web_index_filters_by_priority(): void
  {
    $this->seedTasksWithDistinctPriorities();

    $response = $this->actingAs($this->user)->get('/tasks?priority=high');

    $response->assertOk();
    $response->assertSee('Bar task', false);
    $response->assertDontSee('Foo task', false);
    $response->assertDontSee('Baz task', false);
  }

  public function test_web_index_sorts_priority_asc(): void
  {
    $this->seedTasksWithDistinctPriorities();

    $response = $this->actingAs($this->user)->get('/tasks?priority_sort=asc&due_date_sort=asc');

    $response->assertOk();
    $content = $response->getContent();
    $this->assertNotFalse($content);
    $fooPos = strpos($content, 'Foo task');
    $bazPos = strpos($content, 'Baz task');
    $barPos = strpos($content, 'Bar task');
    $this->assertNotFalse($fooPos);
    $this->assertNotFalse($bazPos);
    $this->assertNotFalse($barPos);
    $this->assertLessThan($bazPos, $fooPos);
    $this->assertLessThan($barPos, $bazPos);
  }

  public function test_web_index_sorts_priority_desc(): void
  {
    $this->seedTasksWithDistinctPriorities();

    $response = $this->actingAs($this->user)->get('/tasks?priority_sort=desc&due_date_sort=asc');

    $response->assertOk();
    $content = $response->getContent();
    $this->assertNotFalse($content);
    $fooPos = strpos($content, 'Foo task');
    $bazPos = strpos($content, 'Baz task');
    $barPos = strpos($content, 'Bar task');
    $this->assertNotFalse($fooPos);
    $this->assertNotFalse($bazPos);
    $this->assertNotFalse($barPos);
    $this->assertLessThan($bazPos, $barPos);
    $this->assertLessThan($fooPos, $bazPos);
  }

  public function test_api_index_filters_by_priority(): void
  {
    $this->seedTasksWithDistinctPriorities();

    $response = $this->actingAs($this->user)->getJson('/api/tasks?priority=high');

    $response->assertOk();
    $titles = collect($response->json('data'))->pluck('title')->all();
    $this->assertSame(['Bar task'], $titles);
  }

  public function test_api_index_sorts_priority_asc(): void
  {
    $this->seedTasksWithDistinctPriorities();

    $response = $this->actingAs($this->user)->getJson('/api/tasks?priority_sort=asc&due_date_sort=asc');

    $response->assertOk();
    $titles = collect($response->json('data'))->pluck('title')->all();
    $this->assertSame(['Foo task', 'Baz task', 'Bar task'], $titles);
  }

  public function test_api_index_sorts_priority_desc(): void
  {
    $this->seedTasksWithDistinctPriorities();

    $response = $this->actingAs($this->user)->getJson('/api/tasks?priority_sort=desc&due_date_sort=asc');

    $response->assertOk();
    $titles = collect($response->json('data'))->pluck('title')->all();
    $this->assertSame(['Bar task', 'Baz task', 'Foo task'], $titles);
  }
```

**Step 4-4.** `postman/Task-API.postman_collection.json` 

| **変更内容** | **リクエスト名** | **行** |
| --- | --- | --- |
| POST test スクリプト | `POST /api/tasks (valid)` | **205–210**（207–208 間に追加） |
| PUT body | `PUT /api/tasks/{{taskId}}` | **255** |
| PUT test スクリプト | `PUT /api/tasks/{{taskId}}` | **265**（続けて追加） |
- **POST test スクリプト変更後:**

```json
"pm.test('status 201', () => pm.response.to.have.status(201));",
"const json = pm.response.json();",
"pm.test('priority defaults to medium', () => {",
"  pm.expect(json.data.priority).to.eql('medium');",
"});",
"const id = json.data && json.data.id;",
"if (id) {",
"  pm.collectionVariables.set('taskId', String(id));",
"}"
```

- **PUT body 変更後:**

```json
"raw": "{\n  \"title\": \"Updated from Postman\",\n  \"status\": \"in_progress\",\n  \"priority\": \"high\"\n }"
```

- **PUT test スクリプト変更後:**

```json
"pm.test('status 200', () => pm.response.to.have.status(200));",
"pm.test('response has priority', () => {",
"  pm.expect(pm.response.json().data.priority).to.eql('high');",
"});"
```

**Step 4-5.** CI 相当の品質チェックを実行し、すべて緑にする。

```bash
./scripts/check-quality.sh
```

---

### Phase 5: after_fix メトリクス・記録

**Step 5-1.** 変更をコミットする。

```bash
git add -A
git commit -m "test: update tests and Postman for priority (full list support)"
```

**Step 5-2.** after_fix フェーズのメトリクスを取得する。

```bash
composer experiment:metrics -- --phase after_fix --diff-ref experiment-baseline-v1
```

**Step 5-3.** 実験記録を書き込む。

```bash
composer experiment:record -- --scenario api-spec-change-priority --write
```

**Step 5-4.** 結果を公開ディレクトリにコピーする。

```bash
./scripts/publish-experiment-results.sh --scenario api-spec-change-priority
```

**Step 5-5.** 結果をコミット・プッシュする。

```bash
git add experiment/results/api-spec-change-priority/
git commit -m "$(cat <<'EOF'
docs: publish experiment results for api-spec-change-priority

Record baseline, after_update, and after_fix metrics for the full
priority attribute scenario on the improved architecture.
EOF
)"
git push origin exp/api-spec-change-priority
```

**Step 5-6.** after_fix の CI 緑を確認する（PR は Phase 1 Step 1-2 で作成済みのため新規作成しない）。この push が after_fix の CI（緑）を発火する。

```bash
gh pr checks exp/api-spec-change-priority --watch
gh pr ready exp/api-spec-change-priority   # 任意: draft を Ready に切り替え
```

GitHub Actions 4 ジョブすべて成功を確認し、失敗0を RECORD.md の after_fix 行に記録する。

**Step 5-7.** 結果を公開ディレクトリにコピーする。

```bash
./scripts/publish-experiment-results.sh --scenario api-spec-change-priority
```

**Step 5-8.** 結果を手動で変更し、コミット・プッシュする。

```bash
git add experiment/results/api-spec-change-priority/RECORD.md
git commit -m "$(cat <<'EOF'
docs: fill manual experiment record for api-spec-change-priority
Add CI, work time, commits, and notes to the manual recording table.
EOF
)"
git push origin exp/api-spec-change-priority
```

---

## 5. 完了条件

- [ ]  after_fix で GitHub Actions 4 ジョブすべて成功
- [ ]  各フェーズの GitHub CI を同一 PR に記録済み（baseline / after_update / after_fix）
- [ ]  `experiment/metrics/runs/<run_id>/` に 3 フェーズ JSON がある
- [ ]  API / DB / Web フォームで `priority` が動作する
- [ ]  Web 一覧に優先度列が表示される
- [ ]  `?priority=high` で Web / API 一覧がフィルタされる
- [ ]  `?priority_sort=asc|desc` で Web / API 一覧が並び替えられる
- [ ]  `experiment/results/` に結果がコピーされている

---

## 6. 触らないファイルとその理由

| ファイル | 理由 |
| --- | --- |
| `app/Http/Controllers/API/TaskController.php` | index は `IndexTaskRequest` → `TaskService` 経由。一覧クエリロジック不要 |
| `app/Http/Controllers/Web/TaskController.php` の `index()` | 同上。`update()` の redirect query のみ 1 行変更 |
| `app/Http/Controllers/API/Web` の `normalizeTaskPayload` | improved では Service 層が担当（legacy は Controller も修正） |

**legacy との期待差:** legacy は **Web/API Controller 2 ファイル**に `normalizeTaskPayload` + 一覧クエリが重複。improved は **Repository + Service + IndexTaskRequest** に集約。

## 関連

- [EXPERIMENT.md](../../EXPERIMENT.md) — 実験設計・主評価指標の定義
- [EXPERIMENT.md — メトリクス記録テンプレート](../EXPERIMENT.md#メトリクス記録テンプレート) — スプレッドシート列定義
- [api-spec-change-status-int.md](./api-spec-change-status-int.md) — 既存属性の型変更シナリオ
- [db-schema-change.md](./db-schema-change.md) — クエリ変更シナリオ
