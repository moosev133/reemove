#!/usr/bin/env python3
from __future__ import annotations
import argparse, datetime as dt, json, pathlib


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--gates', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    gates = json.loads(pathlib.Path(args.gates).read_text(encoding='utf-8'))
    output = pathlib.Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    required = gates['automation']['required']
    text = [
        '# ReeMove Phase 15 Automated Quality Report',
        '',
        f"Generated: {dt.datetime.now(dt.timezone.utc).isoformat()}",
        '',
        'This report is generated after the automated pre-release script completes.',
        '',
        '## Automated gates',
        '',
    ]
    text.extend(f'- [x] {item}' for item in required)
    text += [
        '',
        f"Coverage threshold: {gates['coverage']['globalLinePercent']}% global / {gates['coverage']['criticalLinePercent']}% critical code.",
        '',
        '## Manual signoff still required',
        '',
        '- Device matrix and critical journeys',
        '- Accessibility and localization',
        '- Security and privacy review',
        '- Performance and reliability review',
        '- AI safety human review',
        '- Backup, rollback, and incident rehearsal',
    ]
    output.write_text('\n'.join(text) + '\n', encoding='utf-8')
    print(output)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
