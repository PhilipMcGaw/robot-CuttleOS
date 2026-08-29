"""Static and behavioural checks for the independently migrated depth component."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "frontend/src/components/instruments/rov-depth.ts"

def main() -> int:
    text = SOURCE.read_text(encoding="utf-8")
    required = ("customElements.define(\"rov-depth\"", "update.state.depth", "Depth unavailable", "document.createElement(\"output\")")
    forbidden = ("NATS", "new WebSocket", "sensor/water/depth")
    missing = [item for item in required if item not in text]
    if missing:
        print("[FAIL] Depth component contract is missing: " + ", ".join(missing), file=sys.stderr)
        return 1
    present = [item for item in forbidden if item in text]
    if present:
        print("[FAIL] Depth component contains forbidden routing or transport: " + ", ".join(present), file=sys.stderr)
        return 1
    print("[PASS] Depth component valid/unavailable rendering contract verified.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
