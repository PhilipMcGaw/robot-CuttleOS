#!/usr/bin/env bash
set -Eeuo pipefail

DATALOGGER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MONOREPO_ROOT="$(cd "$DATALOGGER_ROOT/.." && pwd)"
VENV="$MONOREPO_ROOT/.venv"

echo "[INFO] Datalogger service dependency installation (using monorepo environment)"
echo "[INFO] Monorepo directory: $MONOREPO_ROOT"
echo "[INFO] Virtual environment: $VENV"

[[ "$(uname -s)" == "Linux" ]] || { echo "[FAIL] This installer supports Linux/Raspberry Pi only." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "[FAIL] Python 3 is unavailable." >&2; exit 1; }

if [[ ! -d "$VENV" ]]; then
  echo "[INFO] Creating monorepo-level Python virtual environment: $VENV"
  python3 -m venv "$VENV"
else
  echo "[INFO] Using existing virtual environment: $VENV"
fi

echo "[INFO] Upgrading pip"
"$VENV/bin/python" -m pip install --upgrade pip || exit 1

echo "[INFO] Installing Datalogger service dependencies from $MONOREPO_ROOT/pyproject.toml"
cd "$MONOREPO_ROOT"
"$VENV/bin/python" -m pip install -e ".[datalogger]" || exit 1

echo "[PASS] Datalogger dependencies installed in monorepo environment: $VENV"
echo "[INFO] Next: start the datalogger service or run other services."
