#!/usr/bin/env bash
# Staging Android App Bundle build for closed-beta validation.
# Uses debug signing when android/key.properties is absent.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$ROOT/../.gradle-home}"
export TMPDIR="${TMPDIR:-$ROOT/../.tmp}"
mkdir -p "$GRADLE_USER_HOME" "$TMPDIR"
AVAIL_KB="$(df -k "$ROOT" | awk 'NR==2 {print $4}')"
MIN_KB=$((5 * 1024 * 1024))
if [[ "$AVAIL_KB" -lt "$MIN_KB" ]]; then
  echo "Need at least 5 GiB free disk for Android release build (have $((AVAIL_KB / 1024 / 1024)) GiB)." >&2
  exit 4
fi
flutter pub get
flutter build appbundle \
  --release \
  --dart-define=APP_FLAVOR=staging \
  --dart-define=ENABLE_APP_CHECK=false \
  "$@"

