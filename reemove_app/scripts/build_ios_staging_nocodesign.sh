#!/usr/bin/env bash
# iOS release validation without codesigning (CI / local smoke).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

AVAIL_KB="$(df -k "$ROOT" | awk 'NR==2 {print $4}')"
MIN_KB=$((5 * 1024 * 1024))
if [[ "$AVAIL_KB" -lt "$MIN_KB" ]]; then
  echo "Need at least 5 GiB free disk for iOS release build (have $((AVAIL_KB / 1024 / 1024)) GiB)." >&2
  exit 4
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Full Xcode is required (xcodebuild not available). Install Xcode and run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 5
fi

flutter pub get
if [[ ! -f ios/Podfile ]]; then
  echo "ios/Podfile missing — run from a complete Flutter iOS project." >&2
  exit 3
fi

pushd ios >/dev/null
pod install
popd >/dev/null

# macOS resource forks break codesign of Flutter native assets.
xattr -cr "$ROOT" 2>/dev/null || true
rm -rf "$ROOT/build/native_assets" "$ROOT/build/ios" "$ROOT/build/ios_derived"

DERIVED="$ROOT/build/ios_derived"
ARTIFACT="$ROOT/build/ios/iphoneos/Runner.app"
ALT_ARTIFACT="$ROOT/build/ios/Release-iphoneos/Runner.app"

set +e
flutter build ios \
  --release \
  --no-codesign \
  --dart-define=APP_FLAVOR=staging \
  --dart-define=ENABLE_APP_CHECK=false \
  "$@"
FLUTTER_RC=$?
set -e

# Strip xattrs again after Flutter generate/native-assets step.
xattr -cr "$ROOT/build" 2>/dev/null || true

if [[ "$FLUTTER_RC" -ne 0 ]] || [[ ! -x "$ARTIFACT/Runner" && ! -x "$ALT_ARTIFACT/Runner" ]]; then
  echo "Flutter device build needs unsigned xcodebuild fallback (rc=$FLUTTER_RC)."
  flutter build ios \
    --config-only \
    --release \
    --no-codesign \
    --dart-define=APP_FLAVOR=staging \
    --dart-define=ENABLE_APP_CHECK=false \
    "$@"
  xattr -cr "$ROOT/build" 2>/dev/null || true
  pushd ios >/dev/null
  xcodebuild \
    -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$DERIVED" \
    SYMROOT="$DERIVED/Build/Products" \
    OBJROOT="$DERIVED/Build/Intermediates.noindex" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY=- \
    DEVELOPMENT_TEAM= \
    OTHER_CODE_SIGN_FLAGS="--generate-entitlement-der" \
    build
  popd >/dev/null
  DERIVED_APP="$DERIVED/Build/Products/Release-iphoneos/Runner.app"
  mkdir -p "$ROOT/build/ios/iphoneos"
  if [[ -d "$DERIVED_APP" ]]; then
    rm -rf "$ARTIFACT"
    cp -R "$DERIVED_APP" "$ARTIFACT"
  fi
fi

if [[ -x "$ARTIFACT/Runner" ]]; then
  echo "Built: $ARTIFACT"
  du -sh "$ARTIFACT"
  file "$ARTIFACT/Runner"
elif [[ -x "$ALT_ARTIFACT/Runner" ]]; then
  echo "Built: $ALT_ARTIFACT"
  du -sh "$ALT_ARTIFACT"
  file "$ALT_ARTIFACT/Runner"
else
  echo "Unsigned Runner.app binary not found." >&2
  exit 6
fi
