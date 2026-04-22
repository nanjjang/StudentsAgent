#!/bin/sh

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BACKEND_PID=""
BACKEND_STARTED=0
BACKEND_PORT="${BACKEND_PORT:-}"
BACKEND_ORIGIN=""

is_port_in_use() {
  lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

cleanup() {
  if [ "${BACKEND_STARTED}" -eq 1 ] && [ -n "${BACKEND_PID}" ] && kill -0 "${BACKEND_PID}" 2>/dev/null; then
    kill "${BACKEND_PID}" 2>/dev/null || true
    wait "${BACKEND_PID}" 2>/dev/null || true
  fi
}

wait_for_backend() {
  ATTEMPT=0
  while [ "${ATTEMPT}" -lt 30 ]; do
    if curl -fsS "${BACKEND_ORIGIN}/health" >/dev/null 2>&1; then
      return 0
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 0.3
  done
  return 1
}

trap cleanup EXIT INT TERM

cd "${ROOT_DIR}"

if [ -z "${BACKEND_PORT}" ]; then
  for PORT_CANDIDATE in 8000 8001 8002 8010; do
    if ! is_port_in_use "${PORT_CANDIDATE}"; then
      BACKEND_PORT="${PORT_CANDIDATE}"
      break
    fi
  done
fi

if [ -z "${BACKEND_PORT}" ]; then
  BACKEND_PORT=8001
fi

BACKEND_ORIGIN="http://localhost:${BACKEND_PORT}"

echo "Starting StudyAgents backend on ${BACKEND_ORIGIN}"
./venvs/bin/uvicorn app.main:app --reload --port "${BACKEND_PORT}" &
BACKEND_PID="$!"
BACKEND_STARTED=1

if ! wait_for_backend; then
  echo "StudyAgents backend failed to start on ${BACKEND_ORIGIN}" >&2
  exit 1
fi

FRONTEND_PORT="${FRONTEND_PORT:-}"

if [ -z "${FRONTEND_PORT}" ]; then
  for PORT_CANDIDATE in 3000 3001 3002 3003 3010; do
    if ! is_port_in_use "${PORT_CANDIDATE}"; then
      FRONTEND_PORT="${PORT_CANDIDATE}"
      break
    fi
  done
fi

if [ -z "${FRONTEND_PORT}" ]; then
  FRONTEND_PORT=3001
fi

echo "Starting StudyAgents frontend on http://localhost:${FRONTEND_PORT} (proxying to ${BACKEND_ORIGIN})"

cd "${ROOT_DIR}/frontend"
STUDY_AGENTS_BACKEND_ORIGIN="${BACKEND_ORIGIN}" npm run dev:web -- --port "${FRONTEND_PORT}"
