#!/usr/bin/env python3
"""Validate Phase 16 release configuration syntax (no secrets required)."""
from __future__ import annotations

import json
import pathlib
import sys

ROOT_DEFAULT = pathlib.Path('.')


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ROOT_DEFAULT)
    errors: list[str] = []

    required_files = [
        'config/environments.yaml',
        'config/release_channels.yaml',
        'config/production_readiness.yaml',
        'config/remote_config.defaults.json',
        'config/monitoring_thresholds.json',
        'remoteconfig.template.json',
        'dart_defines/prod.json.example',
        'dart_defines/staging.json.example',
        'dart_defines/dev.json.example',
        '.firebaserc.example',
    ]
    for rel in required_files:
        if not (root / rel).exists():
            errors.append(f'missing {rel}')

    for rel in [
        'config/remote_config.defaults.json',
        'config/monitoring_thresholds.json',
        'remoteconfig.template.json',
        'dart_defines/prod.json.example',
        'dart_defines/staging.json.example',
        'dart_defines/dev.json.example',
        '.firebaserc.example',
    ]:
        path = root / rel
        if not path.exists():
            continue
        try:
            json.loads(path.read_text(encoding='utf-8'))
        except Exception as exc:  # noqa: BLE001
            errors.append(f'invalid JSON {rel}: {exc}')

    for rel in [
        'config/environments.yaml',
        'config/release_channels.yaml',
        'config/production_readiness.yaml',
    ]:
        path = root / rel
        if path.exists():
            text = path.read_text(encoding='utf-8')
            if 'schema_version' not in text and 'channels' not in text and 'readiness' not in text:
                # Minimal structural check without requiring PyYAML.
                if len(text.strip()) < 8:
                    errors.append(f'{rel}: empty or invalid')

    prod_example = root / 'dart_defines/prod.json.example'
    if prod_example.exists():
        try:
            prod = json.loads(prod_example.read_text(encoding='utf-8'))
            if prod.get('APP_FLAVOR') != 'production':
                errors.append('prod dart defines must set APP_FLAVOR=production')
            if prod.get('FIREBASE_FUNCTIONS_REGION') != 'europe-west1':
                errors.append('prod dart defines must use europe-west1')
            if prod.get('USE_FIREBASE_EMULATORS') is True:
                errors.append('prod dart defines must not enable emulators')
        except Exception as exc:  # noqa: BLE001
            errors.append(f'prod dart defines parse error: {exc}')

    firebaserc = root / '.firebaserc.example'
    if firebaserc.exists():
        try:
            aliases = json.loads(firebaserc.read_text(encoding='utf-8')).get(
                'projects', {}
            )
            for required in ('development', 'staging', 'production'):
                if required not in aliases:
                    errors.append(f'.firebaserc.example missing alias {required}')
        except Exception as exc:  # noqa: BLE001
            errors.append(f'.firebaserc.example parse error: {exc}')

    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print('Release configuration syntax passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
