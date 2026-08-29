#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$PROJECT_ROOT/.venv"

[[ "$(uname -s)" == "Linux" ]] || { echo "[FAIL] This installer supports Linux/Raspberry Pi only." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "[FAIL] Python 3 is unavailable." >&2; exit 1; }

python3 -m venv "$VENV"
"$VENV/bin/python" -m pip install --upgrade pip
"$VENV/bin/python" -m pip install -r "$PROJECT_ROOT/requirements.txt"
echo "[PASS] Datalogger dependencies installed in $VENV"
