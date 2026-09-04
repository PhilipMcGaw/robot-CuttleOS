#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
FRONTEND_DIR="${PROJECT_ROOT}/frontend/cockpit"
STATIC_DIR="${PROJECT_ROOT}/cockpit/src/rov_cockpit/static"

banner() {
  echo
  echo "======================================================================"
  echo "  $*"
  echo "======================================================================"
  echo
}

section() {
  echo
  echo "----------------------------------------------------------------------"
  echo "  $*"
  echo "----------------------------------------------------------------------"
  echo
}

info() { echo "[INFO] $*"; }
pass() { echo "[PASS] $*"; }
warn() { echo "[WARN] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

banner "CuttleOS — Build Frontend"

section "Frontend Source"
[[ -f "${FRONTEND_DIR}/package.json" ]] || fail "Frontend package manifest not found: ${FRONTEND_DIR}/package.json"
info "Frontend: ${FRONTEND_DIR}"
info "Static output: ${STATIC_DIR}"

section "Node.js / npm"
NPM="${PROJECT_ROOT}/node-runtime/bin/npm"
if [[ ! -x "$NPM" ]] && command -v npm >/dev/null 2>&1; then
  NPM="$(command -v npm)"
fi
if [[ ! -x "$NPM" ]]; then
  warn "npm was not found; retaining the existing compiled frontend in static/dist."
  banner "Frontend Build Skipped"
  exit 0
fi
info "Using npm: $NPM"

section "Frontend Dependencies"
"$NPM" --prefix "${FRONTEND_DIR}" install --no-audit --no-fund
pass "Frontend dependencies installed."

section "TypeScript Build"
"$NPM" --prefix "${FRONTEND_DIR}" run build
pass "TypeScript frontend compiled successfully."

section "Runtime Assets"
PICO_SOURCE="${FRONTEND_DIR}/node_modules/@picocss/pico/css/pico.css"
if [[ -f "$PICO_SOURCE" ]]; then
  cp "$PICO_SOURCE" "${STATIC_DIR}/css/pico.css"
  pass "Pico CSS copied to runtime assets."
fi
VUE_SOURCE="${FRONTEND_DIR}/node_modules/vue/dist/vue.runtime.esm-browser.prod.js"
if [[ -f "$VUE_SOURCE" ]]; then
  mkdir -p "${STATIC_DIR}/dist/vendor"
  cp "$VUE_SOURCE" "${STATIC_DIR}/dist/vendor/vue.runtime.esm-browser.prod.js"
  pass "Vue runtime copied to runtime assets."
fi

banner "Frontend Build Complete"
