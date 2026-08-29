#!/usr/bin/env bash
set -Eeuo pipefail

CONTROL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MONOREPO_ROOT="$(cd "$CONTROL_ROOT/.." && pwd)"
VENV="$MONOREPO_ROOT/.venv"

echo "[INFO] Control service dependency installation (using monorepo environment)"
echo "[INFO] Monorepo directory: $MONOREPO_ROOT"
echo "[INFO] Virtual environment: $VENV"

if [[ "$(uname -s)" != "Linux" && "$(uname -s)" != "Darwin" ]]; then
  echo "[FAIL] This script supports Linux/Raspberry Pi and macOS." >&2
  exit 1
fi
if [[ "$(uname -s)" == "Linux" && "${EUID}" -eq 0 ]]; then
  echo "[FAIL] Run this script as the normal runtime user, not root." >&2
  exit 1
fi

if [[ ! -d "$VENV" ]]; then
  echo "[INFO] Creating monorepo-level Python virtual environment: $VENV"
  python3 -m venv "$VENV"
else
  echo "[INFO] Using existing virtual environment: $VENV"
fi

echo "[INFO] Upgrading pip"
"$VENV/bin/python" -m pip install --upgrade pip || exit 1

echo "[INFO] Installing Control service dependencies from $MONOREPO_ROOT/pyproject.toml"
cd "$MONOREPO_ROOT"
"$VENV/bin/python" -m pip install -e ".[control]" || exit 1

echo "[PASS] Control dependencies installed in monorepo environment: $VENV"
echo "[INFO] Next: start the control service or run other services."
