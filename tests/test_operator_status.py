"""Status-contract checks for the shared Cockpit operator alert surface."""

import asyncio
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]

import sys

sys.path.insert(0, str(ROOT / "src"))

from rov_cockpit.app import system_status


def request_with_nats_client(client: object | None) -> SimpleNamespace:
    return SimpleNamespace(app=SimpleNamespace(state=SimpleNamespace(nats_client=client)))


def test_system_status_reports_nats_and_simulation_state() -> None:
    with patch("rov_cockpit.app.simulation_enabled", False):
        offline = asyncio.run(system_status(request_with_nats_client(None)))
        online = asyncio.run(
            system_status(request_with_nats_client(SimpleNamespace(is_connected=True)))
        )
    with patch("rov_cockpit.app.simulation_enabled", True):
        simulated = asyncio.run(
            system_status(request_with_nats_client(SimpleNamespace(is_connected=True)))
        )

    assert offline == {"nats_connected": False, "simulation_enabled": False}
    assert online == {"nats_connected": True, "simulation_enabled": False}
    assert simulated == {"nats_connected": True, "simulation_enabled": True}


def test_shared_alert_has_all_operator_states() -> None:
    header = (ROOT / "src" / "rov_cockpit" / "templates" / "header.jinja").read_text(encoding="utf-8")
    frontend = (ROOT / "frontend" / "src" / "main.ts").read_text(encoding="utf-8")
    simulator = (ROOT / "src" / "rov_cockpit" / "templates" / "simulator.jinja").read_text(encoding="utf-8")

    assert "data-cockpit-alert" in header
    assert 'fetch("/api/system/status"' in frontend
    assert 'show("Simulation mode", "simulation")' in frontend
    assert 'show("NATS offline", "nats-offline")' in frontend
    assert 'show("No recent alerts.", "normal")' in frontend
    assert "cockpit-system-status-changed" in simulator


def main() -> int:
    test_system_status_reports_nats_and_simulation_state()
    test_shared_alert_has_all_operator_states()
    print("[PASS] Shared operator status states and alert presentation verified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
