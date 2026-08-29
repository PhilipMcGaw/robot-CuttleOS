"""Static checks for the live-view diagnostics tray."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_network_rate_is_in_the_collapsible_left_diagnostic_tray() -> None:
    page = (ROOT / "src" / "rov_cockpit" / "templates" / "home.jinja").read_text(encoding="utf-8")
    styles = (ROOT / "src" / "rov_cockpit" / "static" / "css" / "cockpit.css").read_text(encoding="utf-8")
    assert "rov-diagnostic-tray" in page
    assert 'id="live-diagnostics" hidden' in page
    assert 'data-diagnostic-toggle' in page
    assert 'id="downloadRate"' in page
    assert 'id="uploadRate"' in page
    assert "network-rate" not in page
    assert "inset:var(--rov-topbar-height) auto var(--rov-command-dock-height) 0" in styles
