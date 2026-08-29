"""Static contracts for the shared Cockpit operator shell."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_hamburger_glyph_has_an_independent_optical_offset():
    """Keep the button centred while aligning its glyph with the ROV identity."""

    styles = (ROOT / "src" / "rov_cockpit" / "static" / "css" / "cockpit.css").read_text(
        encoding="utf-8"
    )

    assert ".rov-menu-toggle { display:inline-flex" in styles
    assert "line-height:1; transform:none; }" in styles
    assert ".rov-menu-toggle > .fa-bars { transform:translateY(.10rem); }" in styles
