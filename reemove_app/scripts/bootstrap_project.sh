#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

command -v flutter >/dev/null || { echo "Flutter is required." >&2; exit 1; }
command -v firebase >/dev/null || { echo "Firebase CLI is required." >&2; exit 1; }

if [[ ! -d android || ! -d ios || ! -d web ]]; then
  TEMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TEMP_DIR"' EXIT
  flutter create \
    --platforms=android,ios,web \
    --org=com.reemove \
    --project-name=reemove \
    "$TEMP_DIR/reemove"
  for platform in android ios web; do
    if [[ ! -d "$platform" ]]; then
      cp -R "$TEMP_DIR/reemove/$platform" "$platform"
    fi
  done
fi

python3 scripts/configure_native_permissions.py
flutter pub get

if ! command -v flutterfire >/dev/null; then
  dart pub global activate flutterfire_cli
fi

pushd functions >/dev/null
npm ci
npm run lint
npm run build
popd >/dev/null

pushd firebase_tests >/dev/null
npm ci
popd >/dev/null

flutter analyze
flutter test

echo "ReeMove Phase 4 onboarding foundation is ready. Configure Firebase providers and native capabilities, then run npm run verify:backend."
