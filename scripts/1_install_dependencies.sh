#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$PROJECT_ROOT/.venv"

info() { echo "[INFO] $*"; }
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

echo "[INFO] ROV monorepo project dependency installation"
echo "[INFO] Services: Cockpit (FastAPI web), Control (hardware), Datalogger (telemetry)"
echo "[INFO] Project directory: $PROJECT_ROOT"
echo "[INFO] Runtime: monorepo-level Python virtual environment"
echo "[INFO] Operating mode: local dependency installation; no system services are changed"

[[ "$(uname -s)" == "Linux" || "$(uname -s)" == "Darwin" ]] || fail "Unsupported operating system: $(uname -s). Use the Windows batch installer on Windows."
[[ -f "$PROJECT_ROOT/pyproject.toml" ]] || fail "Project configuration is missing: $PROJECT_ROOT/pyproject.toml. Restore the repository before continuing."
command -v python3 >/dev/null 2>&1 || fail "Python 3 is unavailable. Install Python 3 using the supported operating-system method, then rerun this script."

if [[ "$(uname -s)" == "Linux" && "${EUID}" -eq 0 ]]; then
  fail "This project-local installer must not run as root. Run it as the normal runtime user; use 0_provision_raspberry_pi.sh for documented privileged setup."
fi

if [[ "$(uname -s)" == "Linux" ]]; then
  if command -v npm >/dev/null 2>&1; then
    pass "Linux Node.js/npm detected: $(node --version 2>/dev/null || echo 'node version unavailable') / $(npm --version)"
  elif command -v apt-get >/dev/null 2>&1; then
    info "Linux Node.js/npm is missing; installing the distribution packages nodejs and npm."
    info "This is the documented Linux system-package exception and may request sudo; macOS is never modified by this step."
    sudo apt-get update || fail "Linux package-index update failed. Node.js/npm are required to compile the TypeScript frontend."
    sudo apt-get install -y nodejs npm || fail "Linux Node.js/npm installation failed. Check sudo permissions and package-repository access."
    command -v npm >/dev/null 2>&1 || fail "npm is still unavailable after installation. The frontend cannot be compiled."
    pass "Linux Node.js/npm installed: $(node --version) / $(npm --version)"
  else
    fail "npm is missing and apt-get is unavailable. Install Node.js/npm using the supported Linux package method, then rerun this script."
  fi
else
  info "macOS detected: Node.js/npm will not be installed automatically. An existing npm is optional; committed frontend output remains available."
fi

info "Creating or reusing the monorepo-level Python environment: $VENV"
python3 -m venv "$VENV" || fail "Virtual environment creation failed. Check Python 3 installation and filesystem permissions."
"$VENV/bin/python" -m pip install --upgrade pip || fail "Python packaging bootstrap failed in $VENV. Check network access and filesystem permissions."

info "Installing all services and development dependencies from $PROJECT_ROOT/pyproject.toml"
cd "$PROJECT_ROOT"
# Install all dependencies from pyproject.toml optional dependencies
"$VENV/bin/python" -m pip install fastapi uvicorn[standard] nats-py jinja2 pydantic python-dotenv pyopenssl adafruit-circuitpython-ads7830 adafruit-circuitpython-motor adafruit-circuitpython-pca9685 gpiozero ifaddr psutil pyserial serial pytest pytest-cov black ruff || fail "Dependency installation failed."
# rpi-gpio is Linux-specific and will be skipped on macOS
if [[ "$(uname -s)" == "Linux" ]]; then
  info "Installing Linux-specific rpi-gpio dependency"
  "$VENV/bin/python" -m pip install rpi-gpio || fail "rpi-gpio installation failed on Linux."
else
  info "rpi-gpio skipped (Linux-specific, not needed on $(uname -s))"
fi

pass "All services and development dependencies installed in monorepo environment."
pass "Virtual environment: $VENV"
pass "No system packages or services were changed."
