# 実験設計（改良構成）

本リポジトリは、技術更新時の影響を定量評価するための **改良構成（良い例）** の実験台です。

## 研究ゴール

**設計（モジュール化 + CI/CD）が、技術更新時の影響をどれだけ抑えられるか**を、従来構成（別リポジトリ）と比較して定量的に示す。

| 比較軸 | 従来構成（別リポジトリ） | 本リポジトリ（改良構成） |
|--------|-------------------------|-------------------------|
| 構造 | モノリシック、Controller にロジック集中、DB 直接操作 | Controller / Service / Repository 分離、Interface による抽象化 |
| CI/CD | 本リポジトリと **同一ワークフロー** をコピーして揃える | GitHub Actions（4 ジョブ） |
| アプリ | 同一機能のタスク管理（Laravel） | 同一 |

## 本リポジトリの役割

- 改良構成の **ベースライン** を確立する（**`main` ブランチ = `experiment-baseline-v1` 相当**。タスク属性は `title` / `description` / `due_date` / `status` の 4 項目のみ）
- 更新シナリオ（例: `api-spec-change-status-int` / `api-spec-change-priority`）は **`exp/*` ブランチ** で実施し、ベースラインと混在させない
- 更新シナリオ実施後のメトリクスを記録する
- 従来構成リポジトリ作成時の **クローン元** となる

従来構成は別リポジトリ（`tech-update-task-app-legacy`）で管理します（本リポジトリでは実施しません）。

## 比較条件

| 項目 | 内容 |
|------|------|
| アプリケーション | タスク管理（Web + REST API） |
| 技術スタック | Laravel 13、PHP 8.4、PostgreSQL、Breeze、Vite |
| 評価スコープ | **アプリ全体**（認証・プロフィール・タスク・CI 全ジョブ） |

### アーキテクチャの範囲

- **タスク領域（改良の核）:** `Controller` → `TaskService` → `TaskRepositoryInterface` → `TaskRepository` → Eloquent
- **認証・プロフィール:** Laravel Breeze 標準（Controller から Model 直接）。構造は「悪い例」だが、Laravel / テストツール / JS 更新の影響は **全体メトリクスに含める**

## 更新シナリオ

各シナリオの手順は [scenarios/](./scenarios/) を参照してください。

### 主シナリオ（3 件）

| # | シナリオ | ドキュメント |
|---|----------|--------------|
| 1 | API 仕様変更: status integer 化 | [api-spec-change-status-int.md](./scenarios/api-spec-change-status-int.md) |
| 2 | API 仕様変更: priority 追加 | [api-spec-change-priority.md](./scenarios/api-spec-change-priority.md) |
| 3 | DB / クエリ変更（タイトル検索） | [db-schema-change.md](./scenarios/db-schema-change.md) |

**原則:** 1 シナリオ = 1 実験ラン。両リポジトリに **同一の変更内容** を適用し、メトリクスを比較する。

### 拡張実験（参考）

以下は主シナリオとは別枠の参考計測です。手順 MD は本リポジトリには含めません。収集済み結果は `tech-update-task-app-legacy` リポジトリの `experiment/results/` を参照してください。

| シナリオ | 結果ディレクトリ（legacy リポジトリ内） |
|----------|----------------------------------------|
| Laravel バージョン更新 | `experiment/results/laravel-upgrade/` |
| テストツール更新 | `experiment/results/test-tool-upgrade/` |
| JavaScript ライブラリ変更 | `experiment/results/js-library-change/` |

## 評価指標

### 主評価指標（構成差の比較に必須）

| 優先 | 指標 | 取得方法 |
|------|------|----------|
| **1** | 修正工数（変更ファイル数・行数） | `composer experiment:metrics -- --diff-ref experiment-baseline-v1` の **`git_app`**（`experiment/results/`・`experiment/metrics/` を除外。**after_fix** フェーズ） |
| **1b** | 修正工数（メタデータ込み・参考） | 同上の **`git`**（結果 JSON 等を含む全体 diff） |
| **2** | 更新直後のテスト失敗数 | 同上の `phpunit.fail` / `newman.fail`（**after_update** フェーズ） |
| **3** | 作業時間（分） | [メトリクス記録テンプレート](#メトリクス記録テンプレート) に手動記録 |

> **注意:** API 仕様変更シナリオ（1・2）では **通過率だけでは改良構成と従来構成の差が出ない** 場合がある。修正ファイル数の差を主に見ること（従来構成では `Web\TaskController` と `API\TaskController` の両方を直すことが多い）。

### 1. 修正工数（主指標）

`after_fix` フェーズで CI が緑になった時点の diff を計測する。**主指標は `git_app`**。`git` はメタデータ込みの参考値。

| 項目 | 取得方法 |
|------|----------|
| 変更ファイル数（主） | `git_app.files_changed` |
| 追加 / 削除行数（主） | `git_app.lines_added` / `git_app.lines_deleted` |
| 変更ファイル数（メタデータ込み） | `git.files_changed` |
| 追加 / 削除行数（メタデータ込み） | `git.lines_added` / `git.lines_deleted` |
| コミット数 | シナリオ開始〜CI 緑まで（手動） |
| 作業時間（分） | [メトリクス記録テンプレート](#メトリクス記録テンプレート) に手動記録 |

**完了基準:** 両リポジトリで CI 全ジョブが成功（`after_fix` フェーズ）。

**CI 結果は 3 フェーズすべてで記録する。** `after_fix` の緑は完了基準だが、`baseline`（緑の起点）と `after_update`（更新でどれだけ壊れたか）の CI 結果も比較材料になる。`exp/*` ブランチは `pull_request` トリガでしか CI が走らないため、**Phase 1（baseline）の時点で draft PR を1本作り、以降の各フェーズの push を同じ PR に積む**（手順は `docs/scenarios/*.md` の Step 1-2）。

### 2. 更新直後のテスト失敗数

通過率（成功 ÷ 総数）は参考値。**構成差の判定には使わない**（API 系シナリオで同一になりうる）。

| 対象 | 成功の定義 |
|------|------------|
| PHPUnit | `php artisan test` の pass |
| Newman | Postman コレクションの `pm.test` 成功数 |
| ESLint | `npm run lint` が exit 0 |
| PHPStan | `composer phpstan` が exit 0（エラー 0 件） |

自動収集: `composer experiment:metrics`（[scripts/collect-experiment-metrics.sh](../scripts/collect-experiment-metrics.sh)）。主に **after_update** の `phpunit.fail` / `newman.fail` を記録する。

### 3. エラー発生率

事前に定義した「エラー」を数える。

| 種別 | 数え方 |
|------|--------|
| PHPUnit 失敗数 | 更新直後（`after_update`）の fail 件数 |
| PHPStan エラー件数 | 更新直後の error 行数 |
| CI ジョブ失敗 | フェーズごとの失敗ジョブ数 ÷ 実行ジョブ数（`baseline` / `after_update` / `after_fix` の 3 点を記録） |
| 手動不具合 | ブラウザ / API で発見したバグ件数（メモ欄） |

## フロントエンドスタック（拡張比較）

本リポジトリおよび従来構成リポジトリの **主実験** は Blade + Tailwind CSS + Vite + Alpine.js で統一している。**React 等の SPA フレームワークへの移行は本リポジトリには含まれない**。

Blade と React の比較は、主シナリオ 3 件とは別枠の **拡張比較** として位置づける。フロントエンド刷新が技術更新の影響範囲に与える差を調べる場合は、別リポジトリまたは別ブランチで同一シナリオを再実施すること。

## 実験フェーズ

| フェーズ | 説明 | メトリクス収集 | GitHub CI |
|----------|------|----------------|-----------|
| `baseline` | 更新前・CI 緑の状態 | `composer experiment:metrics -- --phase baseline` | draft PR を作成し緑を確認 |
| `after_update` | 更新適用直後・テスト未修正 | 同上 `--phase after_update` | 同じ PR に push し結果を記録（赤でも可） |
| `after_fix` | 修正完了・CI 緑 | 同上 `--phase after_fix` | 同じ PR に push し緑を確認 |

各フェーズの push 後は `gh pr checks exp/<scenario> --watch` で CI 完了を待ち、失敗ジョブ数を RECORD.md の手動記入表に記録する。`ci.yml` は `concurrency: cancel-in-progress` のため、待たずに次を push すると前フェーズの run がキャンセルされて結果が残らない。

## ベースラインの確立

改良構成が完成し、CI がすべて成功したら:

```bash
git tag -a experiment-baseline-v1 -m "Experiment baseline: improved architecture"
```

以降のシナリオはこのタグからブランチを切ることを推奨します。

**ベースライン仕様:** タスク属性は `title` / `description` / `due_date` / `status`（string）の **4 項目のみ**。`priority` 追加・status integer 化は各 `exp/*` ブランチで実施する。

## 実験の進め方（概要）

1. ベースライン tag を作成
2. シナリオ用ブランチを切る（例: `exp/api-spec-change-status-int`。各 [scenarios/](./scenarios/) MD を参照）
3. [scenarios/](./scenarios/) に従い更新を適用
4. `after_update` でメトリクス収集
5. テスト・コードを修正し CI を緑にする
6. `after_fix` でメトリクス収集
7. [メトリクス記録テンプレート](#メトリクス記録テンプレート) に記録
8. 従来構成リポジトリ（`tech-update-task-app-legacy`）で 3〜7 を繰り返し、各リポジトリの結果ディレクトリ（下表）で比較

## 結果の配置ルール

legacy / improved で **パス規則が異なる**。シナリオ ID（`<scenario-id>`）は [scenarios/](./scenarios/) の MD ファイル名（拡張子なし）と同一。

| リポジトリ | 配置先 | 公開コマンド例 |
|------------|--------|----------------|
| **legacy**（`tech-update-task-app-legacy`） | `experiment/results/legacy/<scenario-id>/` | `./scripts/publish-experiment-results.sh --scenario legacy/db-schema-change` |
| **improved**（本リポジトリ） | `experiment/results/<scenario-id>/` | `./scripts/publish-experiment-results.sh --scenario db-schema-change` |

| 項目 | ルール |
|------|--------|
| 比較 | 同一 `<scenario-id>` ごとに legacy の `legacy/<scenario-id>/` と improved の `<scenario-id>/` を対応させる |
| 統合サマリー | 両リポジトリの `main` に `experiment/results/COMPARISON.md`（マージせず集約） |

## メトリクス記録テンプレート

スプレッドシート等に転記する列定義。**主指標は `after_fix` のアプリ修正工数**（`app_*` 列 = `git_app`）。`meta_*` 列はメタデータ込み参考値。

### 列定義

| 列 | 説明 | 取得元 |
|----|------|--------|
| `repository` | `legacy` または `improved` | 手動 |
| `scenario` | シナリオ ID（例: `api-spec-change-status-int`） | 手動 |
| `phase` | `baseline` / `after_update` / `after_fix` | 手動 |
| `recorded_at` | ISO 8601 タイムスタンプ | metrics JSON |
| `phpunit_pass` | PHPUnit 成功数 | metrics JSON |
| `phpunit_total` | PHPUnit 総数 | metrics JSON |
| `phpunit_pass_rate` | 通過率（参考） | metrics JSON |
| `newman_pass` | Newman 成功数 | metrics JSON |
| `newman_total` | Newman 総数 | metrics JSON |
| `newman_pass_rate` | 通過率（参考） | metrics JSON |
| `phpstan_errors` | PHPStan エラー件数 | metrics JSON |
| `eslint_ok` | ESLint 成功（1/0） | metrics JSON |
| `ci_jobs_failed` | CI 失敗ジョブ数（3 フェーズ分） | 手動（`gh pr checks exp/<scenario> --watch`） |
| `ci_jobs_total` | CI 実行ジョブ数（通常 4） | 手動（同上） |
| `work_minutes` | 作業時間（分） | **手動** |
| `app_files_changed` | アプリ変更ファイル数（**主指標**） | metrics JSON `git_app.files_changed` |
| `app_lines_added` | アプリ追加行数（**主指標**） | metrics JSON `git_app.lines_added` |
| `app_lines_deleted` | アプリ削除行数（**主指標**） | metrics JSON `git_app.lines_deleted` |
| `meta_files_changed` | メタデータ込み変更ファイル数（参考） | metrics JSON `git.files_changed` |
| `meta_lines_added` | メタデータ込み追加行数（参考） | metrics JSON `git.lines_added` |
| `meta_lines_deleted` | メタデータ込み削除行数（参考） | metrics JSON `git.lines_deleted` |
| `commits` | コミット数 | **手動** |
| `manual_bugs` | 手動で発見した不具合件数 | **手動** |
| `metrics_json` | JSON ファイルへの相対パス | 自動 |
| `notes` | メモ | **手動** |

### 記録例（CSV ヘッダ）

```text
repository,scenario,phase,recorded_at,phpunit_pass,phpunit_total,phpunit_pass_rate,newman_pass,newman_total,newman_pass_rate,phpstan_errors,eslint_ok,ci_jobs_failed,ci_jobs_total,work_minutes,app_files_changed,app_lines_added,app_lines_deleted,meta_files_changed,meta_lines_added,meta_lines_deleted,commits,manual_bugs,metrics_json,notes
```

`composer experiment:record -- --scenario <id> --write` で上記列に沿った `RECORD.md` を生成できます。

## 関連ドキュメント

| ドキュメント | 内容 |
|--------------|------|
| [README.md](../README.md) | プロジェクト概要・クイックスタート |
