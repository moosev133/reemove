#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/scan_secrets.py .
python3 scripts/validate_package.py .
find scripts -name '*.sh' -print0 | xargs -0 -n1 bash -n
