#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-demo-reemove}"
if [[ "$FIREBASE_PROJECT_ID" =~ prod|production ]]; then
  echo "Refusing to run rules tests against a production-looking project ID" >&2
  exit 3
fi
npm run test:rules
