#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COCKPIT_DIR="$PROJECT_ROOT/cockpit/src"

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
fail() { echo "[FAIL] $*" >&2; exit 1; }

banner "CuttleOS — Start Cockpit"

section "Frontend Build"
"$PROJECT_ROOT/scripts/build_frontend.sh" || fail "Frontend build failed."
pass "Frontend build completed."

section "Runtime Selection"
if [[ "$(uname -s)" == "Linux" ]] && command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files cockpit.service >/dev/null 2>&1; then
  if [[ "${EUID}" -ne 0 ]]; then
    info "Restarting through sudo for system service access."
    exec sudo bash "$0" "$@"
  fi
  pass "Installed Cockpit service detected."
  section "System Services"
  info "Restarting Motion, Cockpit, and Nginx."
  systemctl restart motion cockpit nginx
  systemctl --no-pager --full status motion cockpit nginx || true
  pass "System services restarted."
  echo "Cockpit should be available at: http://$(hostname -I | awk '{print $1}')/"
  banner "Cockpit Started"
  exit 0
fi

section "Local Cockpit"
PYTHON="$PROJECT_ROOT/.venv/bin/python"
if [[ ! -x "$PYTHON" ]]; then
  fail "Cockpit environment not found. Run scripts/1_install_dependencies.sh first."
fi
info "Starting Uvicorn on http://0.0.0.0:8080."
info "Cockpit will connect to NATS using its configured NATS_URL."
cd "$COCKPIT_DIR"
exec "$PYTHON" -m uvicorn rov_cockpit.app:app --host 0.0.0.0 --port 8080
