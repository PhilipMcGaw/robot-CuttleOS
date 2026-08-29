import fnmatch, json, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def main():
    if len(sys.argv) < 2: print("[FAIL] Supply changed paths.", file=sys.stderr); return 1
    rules = json.loads((ROOT / "tests/documentation_change_policy.json").read_text())
    paths = [x.replace("\\", "/") for x in sys.argv[1:]]
    docs = any(any(fnmatch.fnmatchcase(x, y) for y in rules["documentation_patterns"]) for x in paths)
    behaviour = [x for x in paths if any(fnmatch.fnmatchcase(x, y) for y in rules["documentation_required_patterns"])]
    if behaviour and not docs: print("[FAIL] Behaviour-affecting files changed without documentation: " + ", ".join(behaviour), file=sys.stderr); return 1
    print(f"[PASS] Documentation coverage checked for {len(paths)} changed file(s)."); return 0
if __name__ == "__main__": raise SystemExit(main())
