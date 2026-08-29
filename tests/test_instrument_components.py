"""Static contract checks for migrated cockpit instrument components."""

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
COMPONENTS = ("rov-battery", "rov-network-status", "rov-depth", "rov-hud")
COMPONENT_CLASSES = ("TelemetryInstrument", "RovDepth", "RovHud")


def main() -> int:
    for name in COMPONENTS:
        source = ROOT / "frontend/src/components/instruments" / f"{name}.ts"
        text = source.read_text(encoding="utf-8") if source.is_file() else ""
        if (
            f'customElements.define("{name}"' not in text
            or not any(component in text for component in COMPONENT_CLASSES)
            or "new WebSocket" in text
            or "NATS" in text
        ):
            print(f"[FAIL] {name} component contract is invalid.", file=sys.stderr)
            return 1
    print(f"[PASS] Verified {len(COMPONENTS)} independent Web Component contracts.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
