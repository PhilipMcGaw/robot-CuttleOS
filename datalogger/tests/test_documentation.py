"""ROV Datalogger documentation currency checks."""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
FILES = ("MASTER_CONTEXT.md", "CONTRIBUTING.md", "docs/README.md", "docs/documentation-policy.md", "docs/status.md")
TERMS = ("Implemented", "Automated-test verification", "Bench-tested", "Production-validated", "Planned or unverified")
REFS = ("src/rov_datalogger/main.py", "src/rov_datalogger/store.py", "tests/test_store.py")
def main():
    missing = [x for x in FILES if not (ROOT / x).is_file()]
    if missing: print("[FAIL] Missing documentation: " + ", ".join(missing), file=sys.stderr); return 1
    text = "\n".join((ROOT / x).read_text(encoding="utf-8") for x in FILES)
    if any(x not in text for x in TERMS): print("[FAIL] Required status terms are missing.", file=sys.stderr); return 1
    status = (ROOT / "docs/status.md").read_text(encoding="utf-8")
    if any(x not in status or not (ROOT / x).exists() for x in REFS): print("[FAIL] Required status references are missing.", file=sys.stderr); return 1
    print(f"[PASS] Documentation currency audit passed for {len(FILES)} required documents."); return 0
if __name__ == "__main__": raise SystemExit(main())
