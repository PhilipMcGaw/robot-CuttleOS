"""Require documentation for behaviour-affecting changed paths."""
import fnmatch, json, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def match(path, pattern): return fnmatch.fnmatchcase(path, pattern)
def main():
    if len(sys.argv) < 2: print('[FAIL] Supply changed repository-relative paths.', file=sys.stderr); return 1
    rules=json.loads((ROOT/'tests/documentation_change_policy.json').read_text(encoding='utf-8'))
    paths=[p.replace('\\','/') for p in sys.argv[1:]]
    docs=any(any(match(p,x) for x in rules['documentation_patterns']) for p in paths)
    behaviour=[p for p in paths if any(match(p,x) for x in rules['documentation_required_patterns'])]
    if behaviour and not docs: print('[FAIL] Behaviour-affecting files changed without documentation: '+', '.join(behaviour), file=sys.stderr); return 1
    print(f'[PASS] Classified {len(paths)} changed file(s); documentation coverage is present where required.')
    return 0
if __name__ == '__main__': raise SystemExit(main())
