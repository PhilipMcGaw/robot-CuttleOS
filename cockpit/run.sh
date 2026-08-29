#!/usr/bin/env bash
set -Eeuo pipefail

COCKPIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONOREPO_ROOT="$(cd "$COCKPIT_ROOT/.." && pwd)"
PYTHON="$MONOREPO_ROOT/.venv/bin/python"

if [[ ! -x "$PYTHON" ]]; then
    echo "[FAIL] Cockpit interpreter is unavailable: $PYTHON" >&2
    echo "[FAIL] The service cannot start without the project virtual environment. Run scripts/1_install_dependencies.sh." >&2
    exit 1
fi

echo "[INFO] Starting ROV Cockpit from $COCKPIT_ROOT"
cd "$COCKPIT_ROOT/src"
exec "$PYTHON" -m uvicorn rov_cockpit.app:app --host 0.0.0.0 --port 8080
