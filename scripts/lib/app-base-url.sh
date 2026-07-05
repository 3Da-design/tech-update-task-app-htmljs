#!/usr/bin/env bash
# htmljs ローカル Docker の HTTP ベース URL（check-quality.sh 等から source）
# .env の APP_HTTP_PORT があれば優先、なければ 8002
set -euo pipefail

_app_base_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_HTTP_PORT="${APP_HTTP_PORT:-8002}"
if [[ -f "${_app_base_root}/.env" ]]; then
  _port_from_env="$(grep -E '^APP_HTTP_PORT=' "${_app_base_root}/.env" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r"' || true)"
  if [[ -n "${_port_from_env}" ]]; then
    APP_HTTP_PORT="${_port_from_env}"
  fi
fi
export APP_HTTP_PORT
export APP_BASE_URL="http://localhost:${APP_HTTP_PORT}"
