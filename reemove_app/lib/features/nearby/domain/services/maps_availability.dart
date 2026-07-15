import 'package:flutter/foundation.dart';

/// Google Maps tile SDK availability for this build.
///
/// Phase 10 wires native Android/iOS API keys through uncommitted local config
/// only (see [docs/GOOGLE_MAPS_SETUP.md]). Web has no Maps key path yet, so the
/// nearby experience soft-falls to list mode instead of inventing credentials.
abstract final class MapsAvailability {
  static bool get isSdkSupported => !kIsWeb;

  static const String unsupportedMessage =
      'Map tiles are unavailable in this build. Nearby results still work in list mode. Configure restricted Android/iOS Maps API keys locally to enable the map (see docs/GOOGLE_MAPS_SETUP.md).';
}
