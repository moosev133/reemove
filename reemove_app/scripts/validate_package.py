#!/usr/bin/env python3
from __future__ import annotations
import csv, json, pathlib, sys

REQUIRED = [
    'quality/quality_gates.json',
    'quality/security_contract.json',
    'quality/test_matrix.csv',
    'quality/critical_user_journeys.csv',
    'docs/MASTER_TEST_STRATEGY.md',
    'docs/SECURITY_AND_PRIVACY_TESTING.md',
    'docs/PERFORMANCE_RELIABILITY_PLAN.md',
]


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.')
    errors = []
    for rel in REQUIRED:
        if not (root / rel).exists(): errors.append(f'missing {rel}')
    for path in root.rglob('*.json'):
        if 'node_modules' in path.parts: continue
        try: json.loads(path.read_text(encoding='utf-8'))
        except Exception as exc: errors.append(f'invalid JSON {path}: {exc}')
    for rel in ['quality/test_matrix.csv', 'quality/critical_user_journeys.csv']:
        path = root / rel
        if path.exists():
            with path.open(encoding='utf-8', newline='') as f:
                rows = list(csv.reader(f))
            if len(rows) < 2 or len({len(row) for row in rows}) != 1:
                errors.append(f'invalid CSV shape {rel}')
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print('Package/config validation passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
