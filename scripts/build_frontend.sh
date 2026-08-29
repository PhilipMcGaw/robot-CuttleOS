#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
FRONTEND_DIR="${PROJECT_ROOT}/frontend/cockpit"
STATIC_DIR="${PROJECT_ROOT}/apps/cockpit/rov_cockpit/static"
printf '%s\n' '[INFO] TypeScript frontend build'
NPM="${PROJECT_ROOT}/node-runtime/bin/npm"
if [[ ! -x "$NPM" ]] && command -v npm >/dev/null 2>&1; then NPM="$(command -v npm)"; fi
if [[ ! -x "$NPM" ]]; then
  printf '%s\n' '[WARN] npm was not found; retaining the existing compiled frontend in static/dist.'
  exit 0
fi
"$NPM" --prefix "${FRONTEND_DIR}" install --no-audit --no-fund
"$NPM" --prefix "${FRONTEND_DIR}" run build
PICO_SOURCE="${FRONTEND_DIR}/node_modules/@picocss/pico/css/pico.css"
if [[ -f "$PICO_SOURCE" ]]; then cp "$PICO_SOURCE" "${STATIC_DIR}/css/pico.css"; fi
printf '%s\n' '[PASS] TypeScript frontend compiled successfully.'
