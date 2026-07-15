#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "flutter is required" >&2; exit 2; }
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
# Coverage gate is report-only until global coverage reaches the Phase 15 target.
python3 scripts/check_coverage.py coverage/lcov.info quality/quality_gates.json || true
