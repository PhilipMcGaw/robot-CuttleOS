#!/bin/bash
#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTROL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="${PYTHON:-$PROJECT_ROOT/.venv/bin/python}"

if [[ ! -x "$PYTHON" ]]; then
  printf '[FAIL] Control virtual environment is missing: %s\n' "$PYTHON" >&2
  printf '[INFO] Run ./scripts/1_install_dependencies.sh first.\n' >&2
  exit 1
fi

cd "$CONTROL_DIR"
exec env PYTHONPATH="$CONTROL_DIR${PYTHONPATH:+:$PYTHONPATH}" "$PYTHON" -m rov_control.main
