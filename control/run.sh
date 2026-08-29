#!/bin/bash
#!/usr/bin/env bash
set -Eeuo pipefail

CONTROL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONOREPO_ROOT="$(cd "$CONTROL_ROOT/.." && pwd)"
PYTHON="${PYTHON:-$MONOREPO_ROOT/.venv/bin/python}"

if [[ ! -x "$PYTHON" ]]; then
  printf '[FAIL] Control virtual environment is missing: %s\n' "$PYTHON" >&2
  printf '[INFO] Run ./scripts/1_install_dependencies.sh first.\n' >&2
  exit 1
fi

exec env PYTHONPATH="$CONTROL_ROOT/src${PYTHONPATH:+:$PYTHONPATH}" "$PYTHON" -m rov_control.main
