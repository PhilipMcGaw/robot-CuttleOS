#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
PYTHONPATH=src .venv/bin/python -m rov_datalogger.main
