# 実験結果（第2章・S1 HTML/JS）

このディレクトリは **第2章「スタック比較」** における本スタック（**S1 / HTML+JS + Laravel API**）の
シナリオ実験結果を格納する場所です。**2026-07-09 時点で第2章のシナリオ実験は未実施**であり、
まだ結果はありません（以前ここにあった `COMPARISON.md` / `.tsv` は第1章 legacy/improved の
コピーだったため削除しました）。

## 収集手順（各シナリオ）

`exp/<scenario-id>` ブランチ上で 3 フェーズのメトリクスを取得し、公開スクリプトでこの配下にコピーします。

```bash
composer experiment:metrics -- --phase baseline    --diff-ref experiment-baseline-v1
composer experiment:metrics -- --phase after_update --diff-ref experiment-baseline-v1
composer experiment:metrics -- --phase after_fix    --diff-ref experiment-baseline-v1
composer experiment:record  -- --scenario <scenario-id> --write
./scripts/publish-experiment-results.sh --scenario <scenario-id>
```

- 結果は `experiment/results/<scenario-id>/`（3 フェーズ JSON + `RECORD.md`）に入ります。
- 対象シナリオ: `api-spec-change-priority` / `db-schema-change` / `api-spec-change-status-int`
  （手順書は `docs/scenarios/` を参照）。

## 指標

- **主指標:** `git_app`（`experiment/results/`・`experiment/metrics/` を除外したアプリ差分）。
- **第2章の分解指標:** `git_frontend`（`public/app/`）/ `git_backend`（`app/ routes/ database/ config/ tests/`）。
  修正がフロント／バックエンドのどちらに集まるか（H1）を数値で示す。

## 統合先

3 スタック（S0 Blade / S1 HTML+JS / S2 React）横断の比較表は、各リポジトリではなく
**`../Research/COMPARISON-STACK.md`**（研究ルート）に集約します。本ディレクトリはスタック単体の
生結果のみを保持します。
