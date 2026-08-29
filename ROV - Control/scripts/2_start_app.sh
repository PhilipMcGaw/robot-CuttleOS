#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script targets Linux/Raspberry Pi systems." >&2
  exit 1
fi

if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files python.service >/dev/null 2>&1; then
  if [[ "${EUID}" -ne 0 ]]; then exec sudo bash "$0" "$@"; fi
  systemctl restart python
  systemctl --no-pager --full status python || true
  exit 0
fi

PYTHON="$PROJECT_ROOT/.venv/bin/python"
if [[ ! -x "$PYTHON" ]]; then
  echo "Control environment not found. Run scripts/1_install_dependencies.sh first." >&2
  exit 1
fi

cd "$PROJECT_ROOT"
exec env PYTHONPATH=src NATS_URL="${NATS_URL:-nats://127.0.0.1:4222}" "$PYTHON" -m rov_control.main
