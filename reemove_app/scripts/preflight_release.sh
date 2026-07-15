#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
required=(flutter firebase node npm git)
for cmd in "${required[@]}"; do
  command -v "$cmd" >/dev/null || {
    echo "Missing $cmd" >&2
    exit 1
  }
done
[[ -f pubspec.lock ]] || {
  echo "pubspec.lock is required" >&2
  exit 1
}
[[ -f functions/package-lock.json ]] || {
  echo "functions/package-lock.json is required" >&2
  exit 1
}
git diff --quiet && git diff --cached --quiet || {
  echo "Working tree must be clean" >&2
  exit 1
}
flutter doctor -v
./scripts/pre_release_gate.sh
python3 scripts/check_release_config.py .
echo "Release preflight passed."
