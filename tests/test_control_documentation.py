"""ROV Control documentation currency checks."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = ("MASTER_CONTEXT.md", "docs/CONTRIBUTING.md", "docs/README.md", "docs/documentation-policy.md", "docs/status.md", "docs/testing.md", "docs/hardware.md")
TERMS = ("Implemented", "Automated-test verification", "Bench-tested", "Production-validated", "Planned or unverified")
ARTIFACTS = ("control/src/rov_control/main.py", "configs/cockpit.service", "scripts/1_install_dependencies.bat", "scripts/2_start_app.bat")

def main() -> int:
    missing = [item for item in REQUIRED if not (ROOT / item).is_file()]
    if missing: print("[FAIL] Missing documentation: " + ", ".join(missing), file=sys.stderr); return 1
    files = [ROOT / "MASTER_CONTEXT.md", ROOT / "docs/CONTRIBUTING.md", *sorted((ROOT / "docs").glob("*.md"))]
    text = "\n".join(p.read_text(encoding="utf-8") for p in files)
    missing_terms = [term for term in TERMS if term not in text]
    if missing_terms: print("[FAIL] Missing status terms: " + ", ".join(missing_terms), file=sys.stderr); return 1
    status = (ROOT / "docs/status.md").read_text(encoding="utf-8")
    missing_refs = [item for item in ARTIFACTS if item not in status or not (ROOT / item).exists()]
    if missing_refs: print("[FAIL] Missing status references: " + ", ".join(missing_refs), file=sys.stderr); return 1
    if any(not re.search(r"^#", p.read_text(encoding="utf-8"), re.MULTILINE) for p in files): print("[FAIL] A maintained document has no Markdown heading.", file=sys.stderr); return 1
    print(f"[PASS] Documentation currency audit passed for {len(files)} maintained documents.")
    return 0

if __name__ == "__main__": raise SystemExit(main())
