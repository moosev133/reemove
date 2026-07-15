# Google Maps setup

## Cloud configuration

Create separate restricted keys for Android and iOS in every Firebase/Google Cloud environment. Enable Maps SDK for Android and Maps SDK for iOS, configure billing and quotas, and restrict each key to the production application identity. Do not reuse unrestricted browser/server keys in the mobile app.

## Generate native projects and patch configuration

```bash
./scripts/bootstrap_project.sh
```

The bootstrap invokes `scripts/configure_google_maps.py`. The script is idempotent and never writes a real key.

### Android

Add this uncommitted entry to `android/local.properties`, or expose the same variable in CI:

```properties
MAPS_API_KEY=YOUR_RESTRICTED_ANDROID_KEY
```

The script adds the `com.google.android.geo.API_KEY` manifest placeholder and Gradle lookup.

### iOS

Copy the example file and add a restricted iOS key:

```bash
cp ios/Flutter/Maps.xcconfig.example ios/Flutter/Maps.xcconfig
```

```xcconfig
MAPS_API_KEY=YOUR_RESTRICTED_IOS_KEY
```

`Maps.xcconfig` is gitignored. The script adds the Info.plist substitution and initializes `GMSServices` before Flutter plugin registration.

## Verification

```bash
python3 scripts/test_configure_google_maps.py
flutter pub get
flutter analyze
flutter test
flutter run
```

Test permission denial, permanent denial, disabled location services, map/list synchronization, clustering, route rendering, dark/light mode, low-connectivity behavior, Android/iOS key restrictions, quota alerts, and release builds before staging approval.

## Web / Chrome

Phase 10 does not wire a Google Maps API key for Flutter web. On web builds the
Nearby experience soft-falls to list mode (no invented credentials). Use Android
or iOS with restricted keys for map tiles.
