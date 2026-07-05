#!/usr/bin/env bash
# htmljs Docker スタックの起動と疎通確認（check-quality.sh 等から source）
# 事前に scripts/lib/app-base-url.sh を source し APP_BASE_URL を export すること
set -euo pipefail

ensure_htmljs_compose_file() {
  local compose_file="${1:?compose file path required}"
  if ! grep -q 'container_name: tech-update-task-app-htmljs-php' "${compose_file}" 2>/dev/null; then
    echo "ERROR: ${compose_file} が htmljs 用ではありません（tech-update-task-app-htmljs-php が未定義）。"
    echo "  他構成とコンテナ名が衝突し、docker compose up で失敗します。"
    exit 1
  fi
}

wait_for_postgres_healthy() {
  local postgres_id
  postgres_id="$(docker compose ps -q postgres)"
  if [[ -z "${postgres_id}" ]]; then
    echo "ERROR: postgres container id not found. docker compose ps で状態を確認してください。"
    exit 1
  fi
  for _ in $(seq 1 30); do
    local health
    health="$(docker inspect -f '{{.State.Health.Status}}' "${postgres_id}" 2>/dev/null || true)"
    if [[ "${health}" == "healthy" ]]; then
      return 0
    fi
    sleep 1
  done
  local health
  health="$(docker inspect -f '{{.State.Health.Status}}' "${postgres_id}" 2>/dev/null || true)"
  echo "ERROR: postgres is not healthy (status=${health}). docker compose logs postgres で確認してください。"
  exit 1
}

wait_for_app_http() {
  local base_url="${1:?APP_BASE_URL required}"
  for _ in $(seq 1 30); do
    if curl -sf "${base_url}/up" > /dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "ERROR: ${base_url}/up に接続できません。docker compose ps / docker compose logs nginx app で確認してください。"
  exit 1
}

ensure_docker_stack_running() {
  local root_dir="${1:?root dir required}"
  local base_url="${2:?base url required}"
  local compose_file="${root_dir}/docker-compose.yml"

  ensure_htmljs_compose_file "${compose_file}"

  echo "== Ensure Docker stack (htmljs: ${base_url}) =="
  docker compose up -d
  wait_for_postgres_healthy
  wait_for_app_http "${base_url}"
}
