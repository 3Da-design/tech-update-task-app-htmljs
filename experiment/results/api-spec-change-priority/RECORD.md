# 実験記録（自動生成）

| 項目 | 値 |
|------|----|
| **run_id** | `run-20260802T000118Z` |
| **シナリオ** | `api-spec-change-priority` |
| **リポジトリ** | `stack-s1` |

手動項目（CI・作業時間・コミット数など）は [手動記入](#manual) の表に追記してください。 スプレッドシートへそのまま貼る場合は [TSV（全列）](#tsv) を使えます。

**修正工数:** 主指標は `git_app`（`experiment/results/`・`experiment/metrics/` を除外したアプリ差分）。 `git` は実験メタデータ（結果 JSON 等）を含む参考値です。

## 自動収集サマリー

| フェーズ | 記録時刻 | PHPUnit | Newman | PHPStan | ESLint |
|:---------|:---------|:--------|:-------|:--------|:-------|
| ベースライン | `20260802T000118Z` | 40/40 (100.0%) | 13/13 (100.0%) | 0 件 | OK |
| 更新直後 | `20260802T005750Z` | 40/40 (100.0%) | 13/13 (100.0%) | 0 件 | OK |
| 修正後 | `20260802T010502Z` | 44/44 (100.0%) | 15/15 (100.0%) | 0 件 | OK |

<a id="manual"></a>

## 手動記入（実験者が追記）

| フェーズ | CI (失敗/総数) | 作業時間 (分) | アプリ変更ファイル | アプリ追加行 | アプリ削除行 | コミット数 | 手動バグ | メモ |
|:---------|:---------------|:--------------|:-------------------|:-------------|:-------------|:-----------|:---------|:-----|
| ベースライン | 0/4 |　5 | 0 | 0 | 0 | 1 | 0 | 全4ジョブ green（基準点・[run 30724473472](https://github.com/3Da-design/tech-update-task-app-htmljs/actions/runs/30724473472) / `06a31b8`）。属性は title/description/due_date/status の4項目。 |
| 更新直後 | 0/4 | 43 | 12 | 97 | 7 | 1 | 1 | 非破壊的な属性追加のため CI 緑（[run 30726177609](https://github.com/3Da-design/tech-update-task-app-htmljs/actions/runs/30726177609) / `36d8872`）。`TaskListFilterTest` の seed は priority 無しでも通過し、テスト・Postman 未更新でも fail 0。 |
| 修正後 | 0/4 | 32 | 15 | 188 | 10 | 1 | 0 | 全4ジョブ green（[run 30726522972](https://github.com/3Da-design/tech-update-task-app-htmljs/actions/runs/30726522972) / `4170791`）。テスト・Postman を priority 対応に更新し PHPUnit 44/44・Newman 15/15 へ拡張。 |

## フェーズ別詳細

### ベースライン (`baseline`)

- **JSON:** [`baseline.json`](experiment/metrics/runs/run-20260802T000118Z/baseline.json)
- **git diff_ref:** `experiment-baseline-v1`
- **git_app（アプリ修正工数・主指標）:** 0 files, +0 / -0 (`（なし）`)
- **git_frontend（フロント別・第2章）:** 0 files, +0 / -0 (`（なし）`)
- **git_backend（バックエンド別・第2章）:** 0 files, +0 / -0 (`（なし）`)
- **git（実験メタデータ込み）:** 0 files, +0 / -0 (`（なし）`)

### 更新直後 (`after_update`)

- **JSON:** [`after_update.json`](experiment/metrics/runs/run-20260802T000118Z/after_update.json)
- **git diff_ref:** `experiment-baseline-v1`
- **git_app（アプリ修正工数・主指標）:** 12 files, +97 / -7 (` 12 files changed, 97 insertions(+), 7 deletions(-)`)
- **git_frontend（フロント別・第2章）:** 2 files, +39 / -2 (` 2 files changed, 39 insertions(+), 2 deletions(-)`)
- **git_backend（バックエンド別・第2章）:** 10 files, +58 / -5 (` 10 files changed, 58 insertions(+), 5 deletions(-)`)
- **git（実験メタデータ込み）:** 12 files, +97 / -7 (` 12 files changed, 97 insertions(+), 7 deletions(-)`)

### 修正後 (`after_fix`)

- **JSON:** [`after_fix.json`](experiment/metrics/runs/run-20260802T000118Z/after_fix.json)
- **git diff_ref:** `experiment-baseline-v1`
- **git_app（アプリ修正工数・主指標）:** 15 files, +188 / -10 (` 15 files changed, 188 insertions(+), 10 deletions(-)`)
- **git_frontend（フロント別・第2章）:** 2 files, +39 / -2 (` 2 files changed, 39 insertions(+), 2 deletions(-)`)
- **git_backend（バックエンド別・第2章）:** 12 files, +141 / -6 (` 12 files changed, 141 insertions(+), 6 deletions(-)`)
- **git（実験メタデータ込み）:** 15 files, +188 / -10 (` 15 files changed, 188 insertions(+), 10 deletions(-)`)

<a id="tsv"></a>

<details>
<summary>スプレッドシート用 TSV（全列）</summary>

```tsv
repository	scenario	phase	recorded_at	phpunit_pass	phpunit_total	phpunit_pass_rate	newman_pass	newman_total	newman_pass_rate	phpstan_errors	eslint_ok	ci_jobs_failed	ci_jobs_total	work_minutes	app_files_changed	app_lines_added	app_lines_deleted	frontend_files_changed	frontend_lines_added	frontend_lines_deleted	backend_files_changed	backend_lines_added	backend_lines_deleted	meta_files_changed	meta_lines_added	meta_lines_deleted	commits	manual_bugs	metrics_json	notes
stack-s1	api-spec-change-priority	baseline	20260802T000118Z	40	40	100.0	13	13	100.0	0	1				0	0	0	0	0	0	0	0	0	0	0	0			experiment/metrics/runs/run-20260802T000118Z/baseline.json	
stack-s1	api-spec-change-priority	after_update	20260802T005750Z	40	40	100.0	13	13	100.0	0	1				12	97	7	2	39	2	10	58	5	12	97	7			experiment/metrics/runs/run-20260802T000118Z/after_update.json	 12 files changed, 97 insertions(+), 7 deletions(-)
stack-s1	api-spec-change-priority	after_fix	20260802T010502Z	44	44	100.0	15	15	100.0	0	1				15	188	10	2	39	2	12	141	6	15	188	10			experiment/metrics/runs/run-20260802T000118Z/after_fix.json	 15 files changed, 188 insertions(+), 10 deletions(-)
```

</details>
