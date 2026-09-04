"""ROV Datalogger documentation currency checks."""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[2]
MONOREPO_ROOT = ROOT
FILES = ("docs/CONTRIBUTING.md", "docs/README.md", "docs/documentation-policy.md", "docs/status.md")
TERMS = ("Implemented", "Automated-test verification", "Bench-tested", "Production-validated", "Planned or unverified")
REFS = ("datalogger/src/rov_datalogger/main.py", "datalogger/src/rov_datalogger/store.py", "datalogger/tests/test_store.py")
def main():
    missing = [x for x in FILES if not (ROOT / x).is_file()]
    if missing: print("[FAIL] Missing documentation: " + ", ".join(missing), file=sys.stderr); return 1
    files_to_read = [(MONOREPO_ROOT / "MASTER_CONTEXT.md"), (MONOREPO_ROOT / "docs/CONTRIBUTING.md")] + [(MONOREPO_ROOT / x) for x in ("docs/README.md", "docs/documentation-policy.md", "docs/status.md")]
    text = "\n".join(p.read_text(encoding="utf-8") for p in files_to_read)
    if any(x not in text for x in TERMS): print("[FAIL] Required status terms are missing.", file=sys.stderr); return 1
    status = (MONOREPO_ROOT / "docs/status.md").read_text(encoding="utf-8")
    if any(x not in status or not (ROOT / x).exists() for x in REFS): print("[FAIL] Required status references are missing.", file=sys.stderr); return 1
    print(f"[PASS] Documentation currency audit passed for {len(FILES) + 1} required documents."); return 0
if __name__ == "__main__": raise SystemExit(main())
