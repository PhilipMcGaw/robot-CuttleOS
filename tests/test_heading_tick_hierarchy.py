"""Static contracts for the ROV HUD heading-tape tick hierarchy."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_north_is_the_only_largest_heading_tick():
    source = (ROOT / "frontend" / "src" / "components" / "instruments" / "rov-hud.ts").read_text(
        encoding="utf-8"
    )
    styles = (ROOT / "src" / "rov_cockpit" / "static" / "css" / "cockpit.css").read_text(
        encoding="utf-8"
    )

    assert "major = a % 15 === 0, north = a === 0" in source
    assert 'north ? "north" : ""' in source
    assert "span.major i { height:.62rem; }" in styles
    assert "span.north i { height:.75rem; border-left-width:2px; }" in styles
    assert "span.cardinal i { height:.75rem" not in styles
