#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$PROJECT_ROOT/.venv"

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

banner "CuttleOS — Install Dependencies"

section "System Checks"
info "Project directory: $PROJECT_ROOT"
info "Runtime: monorepo-level Python virtual environment"
info "Operating system: $(uname -s)"

[[ "$(uname -s)" == "Linux" || "$(uname -s)" == "Darwin" ]] || fail "Unsupported operating system: $(uname -s). Use the Windows batch installer on Windows."
[[ -f "$PROJECT_ROOT/pyproject.toml" ]] || fail "Project configuration is missing: $PROJECT_ROOT/pyproject.toml. Restore the repository before continuing."
command -v python3 >/dev/null 2>&1 || fail "Python 3 is unavailable. Install Python 3 using the supported operating-system method, then rerun this script."

if [[ "$(uname -s)" == "Linux" && "${EUID}" -eq 0 ]]; then
  fail "This project-local installer must not run as root. Run it as the normal runtime user; use 0_provision_rpi.sh for documented privileged setup."
fi

section "Node.js / npm"
if [[ "$(uname -s)" == "Linux" ]]; then
  if command -v npm >/dev/null 2>&1; then
    pass "Linux Node.js/npm detected: $(node --version 2>/dev/null || echo 'node version unavailable') / $(npm --version)"
  elif command -v apt-get >/dev/null 2>&1; then
    info "Linux Node.js/npm is missing; installing the distribution packages nodejs and npm."
    info "This is the documented Linux system-package exception and may request sudo."
    sudo apt-get update || fail "Linux package-index update failed. Node.js/npm are required to compile the TypeScript frontend."
    sudo apt-get install -y nodejs npm || fail "Linux Node.js/npm installation failed. Check sudo permissions and package-repository access."
    command -v npm >/dev/null 2>&1 || fail "npm is still unavailable after installation. The frontend cannot be compiled."
    pass "Linux Node.js/npm installed: $(node --version) / $(npm --version)"
  else
    fail "npm is missing and apt-get is unavailable. Install Node.js/npm using the supported Linux package method, then rerun this script."
  fi
else
  info "macOS detected: Node.js/npm will not be installed automatically. An existing npm is required to compile the frontend."
  command -v npm >/dev/null 2>&1 || warn "npm is unavailable; frontend compilation will not be possible on this machine."
fi

section "Python Environment"
info "Creating or reusing the monorepo-level Python environment: $VENV"
python3 -m venv "$VENV" || fail "Virtual environment creation failed. Check Python 3 installation and filesystem permissions."
"$VENV/bin/python" -m pip install --upgrade pip || fail "Python packaging bootstrap failed in $VENV. Check network access and filesystem permissions."
pass "Python virtual environment ready: $VENV"

section "Python Dependencies"
cd "$PROJECT_ROOT"
info "Installing dependencies declared by pyproject.toml."
"$VENV/bin/python" -m pip install ".[cockpit,control,datalogger,dev]" || fail "Dependency installation failed. Review the pyproject.toml dependency declarations and pip diagnostics above."
pass "Cockpit, Control, Datalogger, and development dependencies installed from pyproject.toml."

banner "Installation Complete"
pass "Virtual environment: $VENV"
pass "Dependency source: pyproject.toml"
pass "No system services were changed."
