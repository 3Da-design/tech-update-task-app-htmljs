#!/usr/bin/env bash
# API の疎通とバリデーション（不正 status → 422）を確認する。BASE は省略時 .env の APP_HTTP_PORT から決定
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/app-base-url.sh
source "${ROOT}/scripts/lib/app-base-url.sh"

BASE="${1:-${APP_BASE_URL}}"

echo "GET ${BASE}/up"
up_code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/up")
echo "  http_code=${up_code} (期待: 200)"

echo "POST ${BASE}/api/tasks (status=invalid)"
post_code=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "${BASE}/api/tasks" \
  -H "Content-Type: application/json" \
  -d '{"title":"t","status":"invalid"}')
echo "  http_code=${post_code} (期待: 422)"

if [[ "${up_code}" == "000" || "${post_code}" == "000" ]]; then
  echo ""
  echo "000 は「サーバに届いていない」状態です。例: Docker が止まっている、URL が誤り、ポート競合。"
  echo "  docker compose ps"
  echo "  docker compose logs -f nginx app"
  exit 1
fi

if [[ "${post_code}" != "422" ]]; then
  echo ""
  echo "POST の期待は 422 です。実際のレスポンス: curl -s -X POST ... (本文を確認)"
  exit 1
fi

echo "OK"
