#!/bin/bash
set -euo pipefail
DATALOGGER_ROOT="$(cd "$(dirname "$0")" && pwd)"
MONOREPO_ROOT="$(cd "$DATALOGGER_ROOT/.." && pwd)"
cd "$DATALOGGER_ROOT"
PYTHONPATH=src "$MONOREPO_ROOT/.venv/bin/python" -m rov_datalogger.main
