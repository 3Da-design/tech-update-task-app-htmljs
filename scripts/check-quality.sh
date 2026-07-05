#!/usr/bin/env bash
# 実行前: PHPStan + ESLint / 実行後: PHPUnit + Newman（Docker 前提）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=lib/app-base-url.sh
source "${ROOT}/scripts/lib/app-base-url.sh"
# shellcheck source=lib/ensure-docker-stack.sh
source "${ROOT}/scripts/lib/ensure-docker-stack.sh"

ensure_docker_stack_running "${ROOT}" "${APP_BASE_URL}"

echo "== PHPStan (実行前・型・構造) =="
docker compose exec -T app composer phpstan

echo ""
echo "== Frontend dependencies (Docker / npm ci) =="
"$ROOT/scripts/npm-docker-ci.sh"

echo ""
echo "== ESLint (実行前・構文・規約) =="
docker compose --profile node run --rm node npm run lint

echo ""
echo "== Frontend build (PHPUnit / Newman 用) =="
docker compose --profile node run --rm node npm run build

echo ""
echo "== PHPUnit (実行後・ロジック) =="
docker compose exec -T app composer test

echo ""
echo "== Newman (実行後・API・セッション) =="
if ! curl -sf "${APP_BASE_URL}/up" > /dev/null 2>&1; then
  echo "WARN: ${APP_BASE_URL}/up に接続できないためスタックを再起動します"
  ensure_docker_stack_running "${ROOT}" "${APP_BASE_URL}"
fi

echo "DB migrate --seed（test@example.com / password）"
docker compose exec -T app php artisan migrate --force --seed

docker compose --profile node run --rm node npm run test:api:docker

echo ""
echo "All checks passed (PHPStan, ESLint, PHPUnit, Newman)."
