#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/run_static_quality.sh
./scripts/run_flutter_tests.sh
./scripts/run_functions_tests.sh
./scripts/run_firebase_rules_tests.sh
python3 scripts/generate_quality_report.py \
  --gates quality/quality_gates.json \
  --output build/quality/phase15_report.md

echo "Automated Phase 15 gates passed. Complete manual/device/security signoff in docs/RELEASE_READINESS_SCORECARD.md."
