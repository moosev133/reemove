#!/usr/bin/env python3
from __future__ import annotations
import json, pathlib, sys


def parse_lcov(path: pathlib.Path) -> tuple[int, int]:
    found = hit = 0
    for line in path.read_text(encoding='utf-8').splitlines():
        if line.startswith('LF:'):
            found += int(line[3:])
        elif line.startswith('LH:'):
            hit += int(line[3:])
    return hit, found


def main() -> int:
    if len(sys.argv) != 3:
        print('usage: check_coverage.py coverage/lcov.info quality/quality_gates.json', file=sys.stderr)
        return 2
    lcov, config = map(pathlib.Path, sys.argv[1:])
    if not lcov.exists() or not config.exists():
        print('coverage or quality-gates file missing', file=sys.stderr)
        return 2
    hit, found = parse_lcov(lcov)
    if found == 0:
        print('No covered lines found in lcov file', file=sys.stderr)
        return 2
    percent = hit * 100.0 / found
    threshold = json.loads(config.read_text(encoding='utf-8'))['coverage']['globalLinePercent']
    print(f'Line coverage: {hit}/{found} = {percent:.2f}% (required {threshold}%)')
    return 0 if percent + 1e-9 >= threshold else 1


if __name__ == '__main__':
    raise SystemExit(main())
