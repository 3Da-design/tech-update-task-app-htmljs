#!/usr/bin/env python3
"""
実験ランの baseline / after_update / after_fix の JSON から、
docs/EXPERIMENT.md のメトリクス記録テンプレートに沿った Markdown 記録（RECORD.md）を生成する。
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

PHASE_ORDER = ("baseline", "after_update", "after_fix")
PHASE_LABELS = {
    "baseline": "ベースライン",
    "after_update": "更新直後",
    "after_fix": "修正後",
}

SPREADSHEET_HEADERS = [
    "repository",
    "scenario",
    "phase",
    "recorded_at",
    "phpunit_pass",
    "phpunit_total",
    "phpunit_pass_rate",
    "newman_pass",
    "newman_total",
    "newman_pass_rate",
    "phpstan_errors",
    "eslint_ok",
    "ci_jobs_failed",
    "ci_jobs_total",
    "work_minutes",
    "app_files_changed",
    "app_lines_added",
    "app_lines_deleted",
    "frontend_files_changed",
    "frontend_lines_added",
    "frontend_lines_deleted",
    "backend_files_changed",
    "backend_lines_added",
    "backend_lines_deleted",
    "meta_files_changed",
    "meta_lines_added",
    "meta_lines_deleted",
    "commits",
    "manual_bugs",
    "metrics_json",
    "notes",
]


def load_json(path: Path) -> dict | None:
    if not path.is_file():
        return None
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def git_section(data: dict | None, key: str) -> dict:
    if data is None:
        return {}
    section = data.get(key)
    if section:
        return section
    if key == "git_app":
        return data.get("git", {})
    return {}


def fmt_rate(rate: object) -> str:
    if rate is None or rate == "":
        return "—"
    try:
        return f"{float(rate):.1f}%"
    except (TypeError, ValueError):
        return str(rate)


def fmt_suite(pass_: object, total: object, rate: object) -> str:
    if total in (None, ""):
        return "—"
    return f"{pass_}/{total} ({fmt_rate(rate)})"


def fmt_eslint(data: dict | None) -> str:
    if data is None:
        return "—"
    es = data.get("eslint", {})
    if es.get("ok"):
        return "OK"
    if "ok" in es:
        return "NG"
    return "—"


def fmt_phpstan(data: dict | None) -> str:
    if data is None:
        return "—"
    ps = data.get("phpstan", {})
    count = ps.get("error_count", "")
    if count == "":
        return "—"
    return f"{count} 件"


def fmt_git_line(section: dict) -> str:
    if not section:
        return "—"
    files_changed = section.get("files_changed", "")
    lines_added = section.get("lines_added", "")
    lines_deleted = section.get("lines_deleted", "")
    stat = section.get("diff_shortstat", "") or "（なし）"
    return f"{files_changed} files, +{lines_added} / -{lines_deleted} (`{stat}`)"


def spreadsheet_row(
    scenario: str,
    phase: str,
    data: dict | None,
    run_id: str,
) -> list[str]:
    if data is None:
        return [
            "improved",
            scenario,
            phase,
            "",
            *([""] * 25),
            f"(missing {phase}.json)",
            "",
        ]

    repo = str(data.get("repository", "improved"))
    recorded = str(data.get("recorded_at", ""))
    php = data.get("phpunit", {})
    nm = data.get("newman", {})
    ps = data.get("phpstan", {})
    es = data.get("eslint", {})
    git_app = git_section(data, "git_app")
    git_frontend = data.get("git_frontend", {})
    git_backend = data.get("git_backend", {})
    git_meta = data.get("git", {})
    json_rel = f"experiment/metrics/runs/{run_id}/{phase}.json"

    return [
        repo,
        scenario,
        phase,
        recorded,
        str(php.get("pass", "")),
        str(php.get("total", "")),
        str(php.get("pass_rate", "")),
        str(nm.get("pass", "")),
        str(nm.get("total", "")),
        str(nm.get("pass_rate", "")),
        str(ps.get("error_count", "")),
        "1" if es.get("ok") else "0",
        "",
        "",
        "",
        str(git_app.get("files_changed", "")),
        str(git_app.get("lines_added", "")),
        str(git_app.get("lines_deleted", "")),
        str(git_frontend.get("files_changed", "")),
        str(git_frontend.get("lines_added", "")),
        str(git_frontend.get("lines_deleted", "")),
        str(git_backend.get("files_changed", "")),
        str(git_backend.get("lines_added", "")),
        str(git_backend.get("lines_deleted", "")),
        str(git_meta.get("files_changed", "")),
        str(git_meta.get("lines_added", "")),
        str(git_meta.get("lines_deleted", "")),
        "",
        "",
        json_rel,
        str(git_app.get("diff_shortstat", "")),
    ]


def repository_label(phases: dict[str, dict | None]) -> str:
    for phase in PHASE_ORDER:
        data = phases.get(phase)
        if data and data.get("repository"):
            return str(data["repository"])
    return "improved"


def build_markdown(run_id: str, scenario: str, phases: dict[str, dict | None]) -> str:
    repo = repository_label(phases)
    lines: list[str] = []

    lines.append("# 実験記録（自動生成）\n\n")
    lines.append("| 項目 | 値 |\n")
    lines.append("|------|----|\n")
    lines.append(f"| **run_id** | `{run_id}` |\n")
    lines.append(f"| **シナリオ** | `{scenario}` |\n")
    lines.append(f"| **リポジトリ** | `{repo}` |\n")
    lines.append(
        "\n手動項目（CI・作業時間・コミット数など）は [手動記入](#manual) の表に追記してください。"
        " スプレッドシートへそのまま貼る場合は [TSV（全列）](#tsv) を使えます。\n"
    )
    lines.append(
        "\n**修正工数:** 主指標は `git_app`（`experiment/results/`・`experiment/metrics/` を除外したアプリ差分）。"
        " `git` は実験メタデータ（結果 JSON 等）を含む参考値です。\n"
    )

    lines.append("\n## 自動収集サマリー\n\n")
    lines.append("| フェーズ | 記録時刻 | PHPUnit | Newman | PHPStan | ESLint |\n")
    lines.append("|:---------|:---------|:--------|:-------|:--------|:-------|\n")
    for phase in PHASE_ORDER:
        label = PHASE_LABELS[phase]
        data = phases.get(phase)
        if data is None:
            lines.append(f"| {label} | — | — | — | — | — |\n")
            continue
        php = data.get("phpunit", {})
        nm = data.get("newman", {})
        recorded = str(data.get("recorded_at", "—"))
        lines.append(
            f"| {label} | `{recorded}` | "
            f"{fmt_suite(php.get('pass'), php.get('total'), php.get('pass_rate'))} | "
            f"{fmt_suite(nm.get('pass'), nm.get('total'), nm.get('pass_rate'))} | "
            f"{fmt_phpstan(data)} | {fmt_eslint(data)} |\n"
        )

    lines.append('\n<a id="manual"></a>\n\n## 手動記入（実験者が追記）\n\n')
    lines.append(
        "| フェーズ | CI (失敗/総数) | 作業時間 (分) | アプリ変更ファイル | アプリ追加行 | アプリ削除行 | コミット数 | 手動バグ | メモ |\n"
    )
    lines.append("|:---------|:---------------|:--------------|:-------------------|:-------------|:-------------|:-----------|:---------|:-----|\n")
    for phase in PHASE_ORDER:
        label = PHASE_LABELS[phase]
        lines.append(f"| {label} | | | | | | | | |\n")

    lines.append("\n## フェーズ別詳細\n\n")
    for phase in PHASE_ORDER:
        label = PHASE_LABELS[phase]
        data = phases.get(phase)
        json_path = f"experiment/metrics/runs/{run_id}/{phase}.json"
        lines.append(f"### {label} (`{phase}`)\n\n")
        if data is None:
            lines.append(f"- **JSON:** `{json_path}` — **なし**\n\n")
            continue
        git_app = git_section(data, "git_app")
        git_frontend = data.get("git_frontend", {})
        git_backend = data.get("git_backend", {})
        git_meta = data.get("git", {})
        diff_ref = git_meta.get("diff_ref") or git_app.get("diff_ref") or ""
        lines.append(f"- **JSON:** [`{phase}.json`]({json_path})\n")
        if diff_ref:
            lines.append(f"- **git diff_ref:** `{diff_ref}`\n")
        lines.append(f"- **git_app（アプリ修正工数・主指標）:** {fmt_git_line(git_app)}\n")
        lines.append(f"- **git_frontend（フロント別・第2章）:** {fmt_git_line(git_frontend)}\n")
        lines.append(f"- **git_backend（バックエンド別・第2章）:** {fmt_git_line(git_backend)}\n")
        lines.append(f"- **git（実験メタデータ込み）:** {fmt_git_line(git_meta)}\n\n")

    lines.append('<a id="tsv"></a>\n\n<details>\n<summary>スプレッドシート用 TSV（全列）</summary>\n\n')
    lines.append("```tsv\n")
    lines.append("\t".join(SPREADSHEET_HEADERS) + "\n")
    for phase in PHASE_ORDER:
        row = spreadsheet_row(scenario, phase, phases.get(phase), run_id)
        lines.append("\t".join(row) + "\n")
    lines.append("```\n\n</details>\n")

    return "".join(lines)


def scenario_from_existing_record(record_path: Path) -> str | None:
    if not record_path.is_file():
        return None
    for line in record_path.read_text(encoding="utf-8").splitlines():
        if "scenario" in line and "`" in line:
            parts = line.split("`")
            if len(parts) >= 2:
                candidate = parts[1].strip()
                if candidate and candidate != "(unset)":
                    return candidate
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate experiment RECORD.md from metrics JSON files.")
    parser.add_argument(
        "--run",
        help="Run directory name under experiment/metrics/runs/. Default: read experiment/metrics/.active-run",
    )
    parser.add_argument(
        "--scenario",
        default="",
        help="Scenario id (e.g. api-spec-change). Default: parse existing RECORD.md or (unset)",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Write to experiment/metrics/runs/<run_id>/RECORD.md",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    metrics_root = root / "experiment" / "metrics"
    active_file = metrics_root / ".active-run"

    run_id = args.run
    if not run_id:
        if not active_file.is_file():
            print("error: no --run and no experiment/metrics/.active-run", file=sys.stderr)
            print(
                "hint: run `composer experiment:metrics -- --phase baseline` first, or pass --run <id>",
                file=sys.stderr,
            )
            return 1
        run_id = active_file.read_text(encoding="utf-8").strip()

    run_dir = metrics_root / "runs" / run_id
    if not run_dir.is_dir():
        print(f"error: run directory not found: {run_dir}", file=sys.stderr)
        return 1

    scenario = args.scenario.strip()
    if not scenario:
        scenario = scenario_from_existing_record(run_dir / "RECORD.md") or "(unset)"

    phases: dict[str, dict | None] = {}
    for phase in PHASE_ORDER:
        phases[phase] = load_json(run_dir / f"{phase}.json")

    md = build_markdown(run_id, scenario, phases)
    print(md)

    if args.write:
        out = run_dir / "RECORD.md"
        out.write_text(md, encoding="utf-8")
        print(f"\nWrote {out}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
