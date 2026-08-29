"""Static presentation checks for shared Vue status instruments."""

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "frontend" / "src" / "vue" / "status-instruments.ts"


def main() -> int:
    text = SOURCE.read_text(encoding="utf-8")
    required = ('"fa-battery-empty"', '"-- %"', '`${clamped} %`')
    missing = [item for item in required if item not in text]
    if missing:
        print("[FAIL] Battery status presentation is missing: " + ", ".join(missing), file=sys.stderr)
        return 1
    if '"Unavailable"' in text:
        print("[FAIL] Battery status must use the compact -- % placeholder, not text.", file=sys.stderr)
        return 1
    print("[PASS] Battery status uses percentage values and the -- % unavailable placeholder.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
