#!/usr/bin/env bash
# 実験メトリクスを収集し experiment/metrics/runs/<run_id>/<phase>.json に出力する
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=lib/app-base-url.sh
source "${ROOT}/scripts/lib/app-base-url.sh"

PHASE="baseline"
RUN_ID=""
DIFF_REF=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase)
      PHASE="${2:?--phase requires a value}"
      shift 2
      ;;
    --run)
      RUN_ID="${2:?--run requires a value}"
      shift 2
      ;;
    --diff-ref)
      DIFF_REF="${2:?--diff-ref requires a value}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

case "$PHASE" in
  baseline | after_update | after_fix) ;;
  *)
    echo "Invalid --phase: $PHASE (use baseline, after_update, or after_fix)" >&2
    exit 1
    ;;
esac

METRICS_DIR="$ROOT/experiment/metrics"
RUNS_DIR="$METRICS_DIR/runs"
ACTIVE_RUN_FILE="$METRICS_DIR/.active-run"

sanitize_run_id() {
  local s="$1"
  s="${s//[^a-zA-Z0-9._-]/_}"
  if [[ ${#s} -gt 80 ]]; then
    s="${s:0:80}"
  fi
  echo "$s"
}

mkdir -p "$RUNS_DIR"

if [[ -z "$RUN_ID" ]]; then
  if [[ "$PHASE" == "baseline" ]]; then
    RUN_ID="run-$(date -u +"%Y%m%dT%H%M%SZ")"
    RUN_ID="$(sanitize_run_id "$RUN_ID")"
    mkdir -p "$RUNS_DIR/$RUN_ID"
    printf '%s' "$RUN_ID" >"$ACTIVE_RUN_FILE"
    echo "== New experiment run: $RUN_ID (saved to experiment/metrics/.active-run) =="
  else
    if [[ ! -f "$ACTIVE_RUN_FILE" ]]; then
      echo "error: no --run and no experiment/metrics/.active-run" >&2
      echo "hint: run baseline first: composer experiment:metrics -- --phase baseline" >&2
      echo "   or: composer experiment:metrics -- --phase $PHASE --run <run_id>" >&2
      exit 1
    fi
    RUN_ID="$(sanitize_run_id "$(tr -d '\n' <"$ACTIVE_RUN_FILE")")"
    echo "== Using active run from .active-run: $RUN_ID =="
  fi
else
  RUN_ID="$(sanitize_run_id "$RUN_ID")"
  mkdir -p "$RUNS_DIR/$RUN_ID"
  if [[ "$PHASE" == "baseline" ]]; then
    printf '%s' "$RUN_ID" >"$ACTIVE_RUN_FILE"
    echo "== Active run set to: $RUN_ID (from --run) =="
  fi
fi

RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR"

TIMESTAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
OUTPUT="$RUN_DIR/${PHASE}.json"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PHPSTAN_EXIT=0
PHPSTAN_ERRORS=0
ESLINT_EXIT=0
BUILD_EXIT=0
PHPUNIT_EXIT=0
NEWMAN_EXIT=0

PHPUNIT_PASS=0
PHPUNIT_FAIL=0
PHPUNIT_TOTAL=0
NEWMAN_PASS=0
NEWMAN_FAIL=0
NEWMAN_TOTAL=0

echo "== Collecting experiment metrics (phase: $PHASE, run: $RUN_ID) =="

echo ">> PHPStan"
set +e
docker compose exec -T app composer phpstan 2>"$TMP_DIR/phpstan.stderr"
PHPSTAN_EXIT=$?
set -e
if [[ -f "$TMP_DIR/phpstan.stderr" ]]; then
  PHPSTAN_ERRORS="$(grep -c '\[ERROR\]' "$TMP_DIR/phpstan.stderr" 2>/dev/null || true)"
  PHPSTAN_ERRORS="${PHPSTAN_ERRORS:-0}"
fi

echo ">> npm dependencies"
if [[ ! -f node_modules/vite/package.json ]]; then
  docker compose --profile node run --rm node sh -c "npm ci --no-audit --no-fund"
fi

echo ">> ESLint"
set +e
docker compose --profile node run --rm node npm run lint 2>"$TMP_DIR/eslint.stderr"
ESLINT_EXIT=$?
set -e

echo ">> Frontend build (PHPUnit / Newman)"
set +e
docker compose --profile node run --rm node npm run build 2>"$TMP_DIR/build.stderr"
BUILD_EXIT=$?
set -e

echo ">> PHPUnit (JUnit)"
JUNIT_HOST="$TMP_DIR/junit.xml"
set +e
docker compose exec -T app sh -c 'mkdir -p storage/framework/testing && php artisan test --log-junit storage/framework/testing/junit.xml'
PHPUNIT_CMD_EXIT=$?
set -e
docker compose cp "app:/var/www/html/storage/framework/testing/junit.xml" "$JUNIT_HOST" 2>/dev/null || true

if [[ -f "$JUNIT_HOST" ]]; then
  read -r PHPUNIT_TOTAL PHPUNIT_FAIL PHPUNIT_PASS < <(
    python3 - "$JUNIT_HOST" <<'PY'
import sys
import xml.etree.ElementTree as ET
path = sys.argv[1]
root = ET.parse(path).getroot()
tests = failures = errors = skipped = 0
for suite in root.iter("testsuite"):
    name = suite.get("name", "")
    if name.endswith("phpunit.xml") or name == "phpunit.xml":
        tests = int(suite.attrib.get("tests", 0))
        failures = int(suite.attrib.get("failures", 0))
        errors = int(suite.attrib.get("errors", 0))
        skipped = int(suite.attrib.get("skipped", 0))
        break
if tests == 0 and root.attrib.get("tests"):
    tests = int(root.attrib.get("tests", 0))
    failures = int(root.attrib.get("failures", 0))
    errors = int(root.attrib.get("errors", 0))
    skipped = int(root.attrib.get("skipped", 0))
fail = failures + errors
print(tests, fail, max(tests - fail - skipped, 0))
PY
  )
  if [[ "$PHPUNIT_FAIL" -gt 0 ]]; then
    PHPUNIT_EXIT=1
  fi
  if [[ "${PHPUNIT_CMD_EXIT:-0}" -ne 0 ]]; then
    PHPUNIT_EXIT=1
  fi
else
  echo "WARN: JUnit XML not found; PHPUnit counts default to 0" >&2
fi

echo ">> Newman"
if ! curl -sf "${APP_BASE_URL}/up" > /dev/null 2>&1; then
  echo "Starting docker compose..."
  docker compose up -d
  for _ in $(seq 1 30); do
    if curl -sf "${APP_BASE_URL}/up" > /dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

docker compose exec -T app php artisan migrate --force --seed

NEWMAN_JSON="$TMP_DIR/newman.json"
NEWMAN_EXPORT="$RUN_DIR/.newman-export.json"
rm -f "$NEWMAN_EXPORT"
set +e
docker compose --profile node run --rm node sh -c \
  "npm run test:api:docker -- \
    --reporters cli,json \
    --reporter-json-export experiment/metrics/runs/${RUN_ID}/.newman-export.json" 2>"$TMP_DIR/newman.stderr"
NEWMAN_EXIT=$?
set -e

if [[ -f "$NEWMAN_EXPORT" ]]; then
  cp "$NEWMAN_EXPORT" "$NEWMAN_JSON"
  rm -f "$NEWMAN_EXPORT"
fi

if [[ -f "$NEWMAN_JSON" ]]; then
  read -r NEWMAN_TOTAL NEWMAN_FAIL NEWMAN_PASS < <(
    python3 - "$NEWMAN_JSON" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
run = data.get("run", {})
stats = run.get("stats", {})
assertions = stats.get("assertions", {})
total = assertions.get("total", 0)
failed = assertions.get("failed", 0)
print(total, failed, total - failed)
PY
  )
fi

parse_git_shortstat() {
  local stat="$1"
  python3 - "$stat" <<'PY'
import re, sys
text = sys.argv[1].strip()
files = additions = deletions = 0
m = re.search(r"(\d+)\s+files?\s+changed", text)
if m:
    files = int(m.group(1))
m = re.search(r"(\d+)\s+insertions?\(\+\)", text)
if m:
    additions = int(m.group(1))
m = re.search(r"(\d+)\s+deletions?\(-\)", text)
if m:
    deletions = int(m.group(1))
print(files, additions, deletions)
PY
}

GIT_SHORTSTAT=""
GIT_FILES_CHANGED=""
GIT_LINES_ADDED=""
GIT_LINES_DELETED=""
GIT_APP_SHORTSTAT=""
GIT_APP_FILES_CHANGED=""
GIT_APP_LINES_ADDED=""
GIT_APP_LINES_DELETED=""
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  if [[ -n "$DIFF_REF" ]]; then
    GIT_SHORTSTAT="$(git diff --shortstat "${DIFF_REF}..HEAD" 2>/dev/null | tr -d '\n' || true)"
    GIT_APP_SHORTSTAT="$(git diff --shortstat "${DIFF_REF}..HEAD" -- . ':(exclude)experiment/results' ':(exclude)experiment/metrics' 2>/dev/null | tr -d '\n' || true)"
  else
    GIT_SHORTSTAT="$(git diff --shortstat 2>/dev/null | tr -d '\n' || true)"
    GIT_APP_SHORTSTAT="$(git diff --shortstat -- . ':(exclude)experiment/results' ':(exclude)experiment/metrics' 2>/dev/null | tr -d '\n' || true)"
  fi
  if [[ -n "$GIT_SHORTSTAT" ]]; then
    read -r GIT_FILES_CHANGED GIT_LINES_ADDED GIT_LINES_DELETED < <(parse_git_shortstat "$GIT_SHORTSTAT")
  fi
  if [[ -n "$GIT_APP_SHORTSTAT" ]]; then
    read -r GIT_APP_FILES_CHANGED GIT_APP_LINES_ADDED GIT_APP_LINES_DELETED < <(parse_git_shortstat "$GIT_APP_SHORTSTAT")
  fi
fi

phpunit_rate="0"
if [[ "$PHPUNIT_TOTAL" -gt 0 ]]; then
  phpunit_rate="$(python3 -c "print(round($PHPUNIT_PASS / $PHPUNIT_TOTAL * 100, 2))")"
fi

newman_rate="0"
if [[ "$NEWMAN_TOTAL" -gt 0 ]]; then
  newman_rate="$(python3 -c "print(round($NEWMAN_PASS / $NEWMAN_TOTAL * 100, 2))")"
fi

export OUTPUT PHASE TIMESTAMP RUN_ID PHPSTAN_EXIT PHPSTAN_ERRORS ESLINT_EXIT BUILD_EXIT PHPUNIT_EXIT NEWMAN_EXIT
export PHPUNIT_PASS PHPUNIT_FAIL PHPUNIT_TOTAL NEWMAN_PASS NEWMAN_FAIL NEWMAN_TOTAL
export phpunit_rate newman_rate GIT_SHORTSTAT GIT_APP_SHORTSTAT DIFF_REF
export GIT_FILES_CHANGED GIT_LINES_ADDED GIT_LINES_DELETED
export GIT_APP_FILES_CHANGED GIT_APP_LINES_ADDED GIT_APP_LINES_DELETED

python3 - <<'PY'
import json, os
doc = {
    "run_id": os.environ["RUN_ID"],
    "phase": os.environ["PHASE"],
    "recorded_at": os.environ["TIMESTAMP"],
    "repository": "improved",
    "phpstan": {
        "exit_code": int(os.environ["PHPSTAN_EXIT"]),
        "error_count": int(os.environ["PHPSTAN_ERRORS"]),
        "ok": int(os.environ["PHPSTAN_EXIT"]) == 0,
    },
    "eslint": {
        "exit_code": int(os.environ["ESLINT_EXIT"]),
        "ok": int(os.environ["ESLINT_EXIT"]) == 0,
    },
    "vite_build": {
        "exit_code": int(os.environ["BUILD_EXIT"]),
        "ok": int(os.environ["BUILD_EXIT"]) == 0,
    },
    "phpunit": {
        "exit_code": int(os.environ["PHPUNIT_EXIT"]),
        "pass": int(os.environ["PHPUNIT_PASS"]),
        "fail": int(os.environ["PHPUNIT_FAIL"]),
        "total": int(os.environ["PHPUNIT_TOTAL"]),
        "pass_rate": float(os.environ["phpunit_rate"]),
        "ok": int(os.environ["PHPUNIT_EXIT"]) == 0,
    },
    "newman": {
        "exit_code": int(os.environ["NEWMAN_EXIT"]),
        "pass": int(os.environ["NEWMAN_PASS"]),
        "fail": int(os.environ["NEWMAN_FAIL"]),
        "total": int(os.environ["NEWMAN_TOTAL"]),
        "pass_rate": float(os.environ["newman_rate"]),
        "ok": int(os.environ["NEWMAN_EXIT"]) == 0,
    },
    "git_app": {
        "diff_ref": os.environ.get("DIFF_REF", "") or None,
        "files_changed": int(os.environ.get("GIT_APP_FILES_CHANGED") or 0),
        "lines_added": int(os.environ.get("GIT_APP_LINES_ADDED") or 0),
        "lines_deleted": int(os.environ.get("GIT_APP_LINES_DELETED") or 0),
        "diff_shortstat": os.environ.get("GIT_APP_SHORTSTAT", ""),
        "excludes": ["experiment/results/", "experiment/metrics/"],
    },
    "git": {
        "diff_ref": os.environ.get("DIFF_REF", "") or None,
        "files_changed": int(os.environ.get("GIT_FILES_CHANGED") or 0),
        "lines_added": int(os.environ.get("GIT_LINES_ADDED") or 0),
        "lines_deleted": int(os.environ.get("GIT_LINES_DELETED") or 0),
        "diff_shortstat": os.environ.get("GIT_SHORTSTAT", ""),
        "includes_experiment_metadata": True,
    },
}
path = os.environ["OUTPUT"]
with open(path, "w") as f:
    json.dump(doc, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"Wrote metrics to {path}")
PY

echo ""
cat "$OUTPUT"
