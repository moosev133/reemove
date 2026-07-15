#!/usr/bin/env bash
set -euo pipefail
version="${1:?version required, e.g. 1.0.0}"
build="${2:?build number required}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][A-Za-z0-9.-]+)?$ ]] || {
  echo "Invalid version" >&2
  exit 2
}
[[ "$build" =~ ^[1-9][0-9]*$ ]] || {
  echo "Invalid build number" >&2
  exit 2
}
cd "$(dirname "$0")/.."
[[ -f dart_defines/prod.json ]] || {
  echo "dart_defines/prod.json missing — copy from dart_defines/prod.json.example and fill owner values locally" >&2
  exit 3
}
mkdir -p build/symbols/ios release_evidence
flutter pub get
flutter build ipa \
  --release \
  --build-name "$version" \
  --build-number "$build" \
  --dart-define-from-file dart_defines/prod.json \
  --obfuscate \
  --split-debug-info="build/symbols/ios/${version}+${build}" \
  --export-options-plist=ios/ExportOptions.plist
sha256sum build/ios/ipa/*.ipa >"release_evidence/ios-${version}+${build}.sha256" || true
flutter --version >"release_evidence/flutter-version-ios-${version}+${build}.txt"
