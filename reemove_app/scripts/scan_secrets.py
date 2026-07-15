#!/usr/bin/env python3
from __future__ import annotations
import pathlib, re, sys

SKIP_DIRS = {'.git', 'build', '.dart_tool', 'node_modules', '.idea', '.vscode'}
PATTERNS = {
    'private key': re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
    'Google API key-like value': re.compile(r'AIza[0-9A-Za-z_-]{30,}'),
    'OpenAI key-like value': re.compile(r'\bsk-[A-Za-z0-9_-]{20,}\b'),
    'GitHub token-like value': re.compile(r'\bgh[pousr]_[A-Za-z0-9]{20,}\b'),
    'hard-coded bearer token': re.compile(r'Authorization\s*[:=]\s*["\']Bearer\s+[A-Za-z0-9._-]{16,}', re.I),
}
ALLOW_EXT = {'.dart', '.ts', '.js', '.mjs', '.json', '.yaml', '.yml', '.md', '.txt', '.sh', '.py', '.xml', '.gradle', '.properties'}


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.')
    findings = []
    for path in root.rglob('*'):
        if not path.is_file() or any(part in SKIP_DIRS for part in path.parts):
            continue
        if path.suffix.lower() not in ALLOW_EXT and path.name not in {'.env', '.env.test.example'}:
            continue
        try:
            text = path.read_text(encoding='utf-8', errors='ignore')
        except OSError:
            continue
        for name, pattern in PATTERNS.items():
            for match in pattern.finditer(text):
                line = text.count('\n', 0, match.start()) + 1
                findings.append((str(path), line, name))
    if findings:
        for path, line, name in findings:
            print(f'{path}:{line}: possible {name}', file=sys.stderr)
        return 1
    print('Secret scan passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
