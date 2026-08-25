# 実験記録（自動生成）

| 項目 | 値 |
|------|----|
| **run_id** | `run-20260724T043737Z` |
| **シナリオ** | `api-spec-change-status-int` |
| **リポジトリ** | `stack-s1` |

手動項目（CI・作業時間・コミット数など）は [手動記入](#manual) の表に追記してください。 スプレッドシートへそのまま貼る場合は [TSV（全列）](#tsv) を使えます。

**修正工数:** 主指標は `git_app`（`experiment/results/`・`experiment/metrics/` を除外したアプリ差分）。 `git` は実験メタデータ（結果 JSON 等）を含む参考値です。

## 自動収集サマリー

| フェーズ | 記録時刻 | PHPUnit | Newman | PHPStan | ESLint |
|:---------|:---------|:--------|:-------|:--------|:-------|
| ベースライン | `20260724T043737Z` | 40/40 (100.0%) | 13/13 (100.0%) | 0 件 | OK |
| 更新直後 | `20260724T051110Z` | 31/40 (77.5%) | 10/13 (76.9%) | 0 件 | OK |
| 修正後 | `20260724T052359Z` | 40/40 (100.0%) | 13/13 (100.0%) | 0 件 | OK |

<a id="manual"></a>

## 手動記入（実験者が追記）

| フェーズ | CI (失敗/総数) | 作業時間 (分) | アプリ変更ファイル | アプリ追加行 | アプリ削除行 | コミット数 | 手動バグ | メモ |
|:---------|:---------------|:--------------|:-------------------|:-------------|:-------------|:-----------|:---------|:-----|
| ベースライン | 0/4 | 5 | 0 | 0 | 0 | 1 | | 全4ジョブ green（基準点）。 |
| 更新直後 | 2/4 | 31 | 11 | 70 | 20 | 1 | | PHP Tests・API Tests(Newman) が失敗。status を int 化、テスト/Postman は意図的に未更新。|
| 修正後 | 0/4 | 22 | 14 | 83 | 33 | 1 | | テスト/Postman を int 対応に更新し復旧（PHPUnit 40/40・Newman 13/13）。|

## フェーズ別詳細

### ベースライン (`baseline`)

- **JSON:** [`baseline.json`](experiment/metrics/runs/run-20260724T043737Z/baseline.json)
- **git diff_ref:** `experiment-baseline-v1`
- **git_app（アプリ修正工数・主指標）:** 0 files, +0 / -0 (`（なし）`)
- **git_frontend（フロント別・第2章）:** 0 files, +0 / -0 (`（なし）`)
- **git_backend（バックエンド別・第2章）:** 0 files, +0 / -0 (`（なし）`)
- **git（実験メタデータ込み）:** 0 files, +0 / -0 (`（なし）`)

### 更新直後 (`after_update`)

- **JSON:** [`after_update.json`](experiment/metrics/runs/run-20260724T043737Z/after_update.json)
- **git diff_ref:** `experiment-baseline-v1`
- **git_app（アプリ修正工数・主指標）:** 11 files, +70 / -20 (` 11 files changed, 70 insertions(+), 20 deletions(-)`)
- **git_frontend（フロント別・第2章）:** 2 files, +10 / -9 (` 2 files changed, 10 insertions(+), 9 deletions(-)`)
- **git_backend（バックエンド別・第2章）:** 9 files, +60 / -11 (` 9 files changed, 60 insertions(+), 11 deletions(-)`)
- **git（実験メタデータ込み）:** 11 files, +70 / -20 (` 11 files changed, 70 insertions(+), 20 deletions(-)`)

### 修正後 (`after_fix`)

- **JSON:** [`after_fix.json`](experiment/metrics/runs/run-20260724T043737Z/after_fix.json)
- **git diff_ref:** `experiment-baseline-v1`
- **git_app（アプリ修正工数・主指標）:** 14 files, +83 / -33 (` 14 files changed, 83 insertions(+), 33 deletions(-)`)
- **git_frontend（フロント別・第2章）:** 2 files, +10 / -9 (` 2 files changed, 10 insertions(+), 9 deletions(-)`)
- **git_backend（バックエンド別・第2章）:** 11 files, +71 / -22 (` 11 files changed, 71 insertions(+), 22 deletions(-)`)
- **git（実験メタデータ込み）:** 14 files, +83 / -33 (` 14 files changed, 83 insertions(+), 33 deletions(-)`)

<a id="tsv"></a>

<details>
<summary>スプレッドシート用 TSV（全列）</summary>

```tsv
repository	scenario	phase	recorded_at	phpunit_pass	phpunit_total	phpunit_pass_rate	newman_pass	newman_total	newman_pass_rate	phpstan_errors	eslint_ok	ci_jobs_failed	ci_jobs_total	work_minutes	app_files_changed	app_lines_added	app_lines_deleted	frontend_files_changed	frontend_lines_added	frontend_lines_deleted	backend_files_changed	backend_lines_added	backend_lines_deleted	meta_files_changed	meta_lines_added	meta_lines_deleted	commits	manual_bugs	metrics_json	notes
stack-s1	api-spec-change-status-int	baseline	20260724T043737Z	40	40	100.0	13	13	100.0	0	1				0	0	0	0	0	0	0	0	0	0	0	0			experiment/metrics/runs/run-20260724T043737Z/baseline.json	
stack-s1	api-spec-change-status-int	after_update	20260724T051110Z	31	40	77.5	10	13	76.92	0	1				11	70	20	2	10	9	9	60	11	11	70	20			experiment/metrics/runs/run-20260724T043737Z/after_update.json	 11 files changed, 70 insertions(+), 20 deletions(-)
stack-s1	api-spec-change-status-int	after_fix	20260724T052359Z	40	40	100.0	13	13	100.0	0	1				14	83	33	2	10	9	11	71	22	14	83	33			experiment/metrics/runs/run-20260724T043737Z/after_fix.json	 14 files changed, 83 insertions(+), 33 deletions(-)
```

</details>
