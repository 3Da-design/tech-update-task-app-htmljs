# シナリオ: DB / クエリ変更（タイトル検索の大文字小文字）

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

タスク一覧の `?title=` 部分一致検索を、PostgreSQL 上で大文字小文字を区別しない挙動に変更する実験です。現状は `where('title', 'like', ...)` による区別あり検索（`TaskRepository` 17 行目）のため、`Important task` に `?title=important` ではヒットしません。

この変更は永続化層のクエリ修正であり、API の入出力形式は変わりません。改良構成と従来構成で「修正が Repository 1 箇所に集約されるか、Controller 2 箇所に分散するか」を比較するのに適したシナリオです。

improved 構成では、本番コードの修正は `TaskRepository::getFiltered` のみに集約されます。Controller・Service・Interface は触りません。テスト追加は Phase 4 で行い、Phase 2 では Repository のクエリのみを変更します。

S1 は API + 静的フロント（`public/app/`）に一本化されており、Blade のタスクルート（`/tasks`）は存在しません。したがって検証は `GET /api/tasks?title=` の API テストのみで行います（S0 Blade 版の web テストは本スタックでは成立しません）。

## 1. 概要

| 項目 | 値 |
| --- | --- |
| リポジトリ | tech-update-task-app-htmljs（S1 / improved） |
| 実験の内容 | タイトル検索を大文字小文字無視にする（`?title=` 部分一致） |
| ブランチ名 | `exp/db-schema-change` |
| 参照MD | `docs/scenarios/db-schema-change.md` |

## 2. 事前条件チェック

- [ ]  experiment-baseline-v1 または CI 緑 — 比較基準タグからブランチを切り、メトリクス diff の参照点を固定するため
- [ ]  Docker 起動 — `check-quality.sh` と PHPUnit / Newman がコンテナ経由で動くため
- [ ]  PostgreSQL — `LIKE` / `LOWER()` の大文字小文字挙動を CI（GitHub Actions の `postgres:16-alpine`）とローカル Docker で一致させるため

## 3. 修正対象ファイル一覧

| # | ファイルパス | 修正箇所 | フェーズ | 作業内容 | 解説（なぜ触るか） |
| --- | --- | --- | --- | --- | --- |
| 1 | `app/Repositories/TaskRepository.php` | `getFiltered()` 15–18 行目 | Phase 2 | `LOWER(title) LIKE ?` に変更 | タイトル検索の大文字小文字無視はクエリ層の責務であり、改良構成ではここだけ直せば Web/API 両方に反映される |
| 2 | `tests/Feature/TaskListFilterTest.php` | `seedTasks()` の直前（baseline 行 69 の後） | Phase 4 | ケース無視テスト 1 件（API）を追加 | 新仕様を自動検証し、回帰を防ぐ。S1 は API 一本化のため、検証は `GET /api/tasks?title=` の 1 件のみ |
| 3 | `postman/Task-API.postman_collection.json` | （任意） | Phase 4 | 変更なしで可 | 現コレクションにタイトルフィルタのリクエストはなく、CI の Newman は既存テストのみ実行されるため必須ではない |

## 4. 実施手順

### Phase 0: ブランチ作成

**この Phase の目的:** `experiment-baseline-v1` から実験ブランチを切り、以降の変更をベースラインと分離する。

**Step 0-1.** 実験ブランチを作成する

```bash
git checkout -b exp/db-schema-change experiment-baseline-v1
```

---

### Phase 1: baseline メトリクス

**この Phase の目的:** 変更前の状態を記録し、あとで diff 比較できるようにする。

**Step 1-1.** baseline フェーズのメトリクスを取得する

```bash
composer experiment:metrics -- --phase baseline --diff-ref experiment-baseline-v1
```

**Step 1-2.** baseline を GitHub に push し、draft PR を作成して CI 緑を確認する

**この Step の目的:** exp ブランチへの push だけでは CI が走らない（push トリガーは `main`/`master` のみ）。フェーズ別の CI 結果を GitHub 上に残すため、この時点で draft PR を1本作り、以降の各 push を同じ PR に積む。ブランチはタグと同一で差分ゼロのため、`gh pr create` を成立させる anchor として空コミットを1つ積む（app ファイル差分を増やさないので `git_app` メトリクスに影響しない）。

```bash
git commit --allow-empty -m "chore(exp): baseline anchor for db-schema-change"
git push -u origin exp/db-schema-change
gh pr create --draft --base main --head exp/db-schema-change \
  --title "exp: db-schema-change" \
  --body "$(cat <<'EOF'
実験用 PR。マージはしない。

## Test plan（フェーズ別 CI）
- [ ] baseline コミットで CI 4 ジョブ緑
- [ ] after_update コミットで CI 結果を記録（本シナリオは fail 0 の可能性が高い）
- [ ] after_fix コミットで CI 4 ジョブすべて成功
EOF
)"
gh pr checks exp/db-schema-change --watch
```

GitHub Actions（4 ジョブ）が緑になることを確認し、失敗0を RECORD.md の baseline 行に記録する。

---

### Phase 2: 変更適用（テスト・Postman 未着手）

**この Phase の目的:** タイトル検索クエリを大文字小文字無視に変更し、本番コード側の仕様変更を完了する（テストはまだ触らない）。

**Step 2-1.** `TaskRepository::getFiltered` のタイトルフィルタを修正する

- **ファイル:** `app/Repositories/TaskRepository.php`
- **場所:** `TaskRepository::getFiltered()` 行 15–18
- **解説:** 現状の `where('title', 'like', ...)` は PostgreSQL でも大文字小文字を区別する。`LOWER` 比較に置き換えることで、Web/API 共通の検索ロジックを Repository 1 箇所で修正できる。
- **変更前:**

```php
    $title = $filters['title'] ?? null;
    if (is_string($title) && $title !== '') {
      $query->where('title', 'like', '%'.$this->escapeLike($title).'%');
    }
```

- **変更後:**

```php
    $title = $filters['title'] ?? null;
    if (is_string($title) && $title !== '') {
      $query->whereRaw('LOWER(title) LIKE ?', ['%'.mb_strtolower($this->escapeLike($title)).'%']);
    }
```

---

### Phase 3: after_update メトリクス

**この Phase の目的:** テスト未修正のまま、どれだけ壊れたかを数値化する。

**Step 3-1.** 変更をコミットする

```bash
git add app/Repositories/TaskRepository.php
git commit -m "$(cat <<'EOF'
feat: タイトル検索を大文字小文字無視に変更（TaskRepository）

EOF
)"
```

**Step 3-2.** after_update フェーズのメトリクスを取得する

```bash
composer experiment:metrics -- --phase after_update --diff-ref experiment-baseline-v1
```

> **補足:** 既存の `TaskListFilterTest` は `title=Foo` で `Foo task` を検索しており、ケース無視化後も通過する。新規のケース無視テストは Phase 4 で追加するため、この時点の `phpunit.fail` は **0 の可能性が高い**（シナリオ MD の「テスト先行追加」手順とは異なるが、Phase 2/4 分離フォーマットに沿った想定内の挙動）。**期待値: PHPUnit 40/40・Newman 13/13**（baseline と同数）。
> 

**Step 3-3.** after_update コミットを push し、CI 結果を確認・記録する

**この Step の目的:** 更新直後の状態を GitHub Actions 上にも残す。本シナリオはこの時点で fail 0（CI 緑）の可能性が高いが、結果に関わらず失敗ジョブ数を RECORD.md の after_update 行に記録する。

```bash
git push origin exp/db-schema-change
gh pr checks exp/db-schema-change --watch
```

> **注意:** `ci.yml` は `concurrency: cancel-in-progress` のため、run が完了する前に次の push（Phase 5）を行うとキャンセルされる。`--watch` で CI 完了を待ってから Phase 4 に進む。

---

### Phase 4: テスト・Postman 修正 → CI 緑

**この Phase の目的:** 新仕様（大文字小文字無視）をテストで固定し、CI を緑にする。

**Step 4-1.** ケース無視テスト 1 件を `TaskListFilterTest` に追加する

- **ファイル:** `tests/Feature/TaskListFilterTest.php`
- **場所:** `test_api_index_sorts_due_date_desc()` の直後（`experiment-baseline-v1` の行 69 の後）、`seedTasks()`（行 71）の前
- **解説:** `Important task` に `?title=important` がヒットすることを API で検証する。Phase 2 で Repository を修正済みのため、このテスト追加後は即座に緑になる想定。
- **変更前:** （該当メソッドなし）
- **変更後:** 以下 1 メソッドを追加

```php
  public function test_api_index_title_search_is_case_insensitive(): void
  {
    Task::query()->create([
      'user_id' => $this->user->id,
      'title' => 'Important task',
      'description' => null,
      'status' => 'todo',
      'due_date' => null,
    ]);

    $response = $this->actingAs($this->user)->getJson('/api/tasks?title=important');

    $response->assertOk();
    $titles = collect($response->json('data'))->pluck('title')->all();
    $this->assertSame(['Important task'], $titles);
  }
```

> **S1 での注意:** S0（Blade）版シナリオには対になる web テスト `test_web_index_title_search_is_case_insensitive()`（`$this->get('/tasks?title=important')` + `assertSee`）があるが、**S1 では追加しない**。S1 は API + 静的フロントに一本化されており `routes/web.php` にタスクルートが無いため、`/tasks` は 404 を返して必ず失敗する。S2（React）も同様に API テストのみで検証する。

**Step 4-2.** CI 品質チェックを実行する

```bash
./scripts/check-quality.sh
```

> **補足:** フロントエンド変更はないため `composer npm:docker-build` は不要。`check-quality.sh` 内で ESLint・Vite build が実行される。
> **期待値:** PHPUnit **41/41**（baseline 40 + 追加 1）・Newman 13/13・PHPStan 0 件・ESLint OK。
> 

---

### Phase 5: after_fix メトリクス・記録

**この Phase の目的:** Phase 4 のテスト変更をコミットし、最終メトリクスを取得・公開して PR と手動記録まで完了する。

**前提:** Phase 4 で `./scripts/check-quality.sh` が緑であること。

**Step 5-1.** 変更をコミットする。

```bash
git add tests/Feature/TaskListFilterTest.php
git commit -m "$(cat <<'EOF'
test: add case-insensitive title search tests

Add web/API filter tests for db-schema-change scenario.
EOF
)"
```

**Step 5-2.** after_fix フェーズのメトリクスを取得する。

```bash
composer experiment:metrics -- --phase after_fix --diff-ref experiment-baseline-v1
```

**Step 5-3.** 実験記録を書き込む。

```bash
composer experiment:record -- --scenario db-schema-change --write
```

**Step 5-4.** 結果を公開ディレクトリにコピーする。

```bash
./scripts/publish-experiment-results.sh --scenario db-schema-change
```

**Step 5-5.** 結果をコミット・プッシュする。

```bash
git add experiment/results/db-schema-change/
git commit -m "$(cat <<'EOF'
docs: publish experiment results for db-schema-change

Record baseline, after_update, and after_fix metrics for the
case-insensitive title search scenario on the improved architecture.
EOF
)"
git push origin exp/db-schema-change
```

**Step 5-6.** after_fix の CI 緑を確認する（PR は Phase 1 Step 1-2 で作成済みのため新規作成しない）。この push が after_fix の CI（緑）を発火する。

```bash
gh pr checks exp/db-schema-change --watch
gh pr ready exp/db-schema-change   # 任意: draft を Ready に切り替え
```

GitHub Actions 4 ジョブすべて成功を確認し、失敗0を RECORD.md の after_fix 行に記録する。

**Step 5-7.** 結果を公開ディレクトリにコピーする。

```bash
./scripts/publish-experiment-results.sh --scenario db-schema-change
```

**Step 5-8.** 結果を手動で変更し、コミット・プッシュする。

```bash
git add experiment/results/db-schema-change/RECORD.md
git commit -m "$(cat <<'EOF'
docs: fill manual experiment record for db-schema-change

Add CI, work time, commits, and notes to the manual recording table.
EOF
)"
git push origin exp/db-schema-change
```

---

## 5. 完了条件

- [ ]  GitHub Actions 4 ジョブ（`php-tests` / `php-quality` / `frontend` / `api-tests`）すべて成功（`after_fix`）
- [ ]  各フェーズの GitHub CI を同一 PR に記録済み（baseline / after_update / after_fix）
- [ ]  `experiment/metrics/runs/<run_id>/` に `baseline` / `after_update` / `after_fix` の 3 フェーズ JSON がある
- [ ]  `experiment/results/` に `publish-experiment-results.sh` の出力がある
- [ ]  `?title=important` で `Important task` が API（一覧取得）でヒットする
- [ ]  既存の `title=Foo` 部分一致テストが引き続き通過する
- [ ]  S0（`tech-update-task-app-improved`）/ S2（`tech-update-task-app-react`）で同一シナリオを実施し、`git_app.files_changed` を比較できる（第2章では legacy は第1章データの参照専用）

## 6. 触らないファイルとその理由

| ファイル | 理由 |
| --- | --- |
| `app/Http/Controllers/API/TaskController.php` | improved 構成のルール。Controller は HTTP 受け渡しのみで、検索ロジックは Service → Repository に委譲される（S1 は API 一本化のため Web Controller は存在しない） |
| `app/Services/TaskService.php` | タイトル文字列の正規化（trim）のみで、大文字小文字変換はクエリ層の責務 |
| `app/Repositories/Contracts/TaskRepositoryInterface.php` | db-schema シナリオでは Repository 実装のみ変更。インターフェースのシグネチャ・PHPDoc は不変 |
| `app/Http/Resources/TaskResource.php` | レスポンス形式の変更はなく、検索挙動のみの変更 |
| `app/Http/Requests/IndexTaskRequest.php` | `title` クエリパラメータの受け入れルールは変更不要 |
| `app/Models/Task.php` | DB スキーマ・Model 属性の変更はない（クエリのみ変更） |
| `database/migrations/*` | カラム追加・型変更はなく、`LOWER()` によるクエリ変更で完結する |
| `public/app/*`（`tasks.html` / `tasks.js`） | フロントの表示・フォームに変更なし（検索は既存の一覧取得 API をそのまま利用） |
| `postman/Task-API.postman_collection.json` | タイトルフィルタのリクエストがなく、CI Newman は既存コレクションで緑のまま（任意で追加可能） |

## 関連

- [EXPERIMENT.md](../../EXPERIMENT.md) — 実験設計・主評価指標の定義
- [EXPERIMENT.md — メトリクス記録テンプレート](../EXPERIMENT.md#メトリクス記録テンプレート) — スプレッドシート列定義
- [api-spec-change-priority.md](./api-spec-change-priority.md) — 属性追加シナリオ
- [api-spec-change-status-int.md](./api-spec-change-status-int.md) — 既存属性の型変更シナリオ
