import '../../app/router/app_routes.dart';
import 'release_state.dart';
import 'remote_config_keys.dart';

/// Maps routes to Remote Config feature flags for closed-beta kill switches.
abstract final class ReleaseFeatureGate {
  /// Returns a safe redirect when [location] targets a disabled feature.
  static String? redirectForLocation(String location, ReleaseState state) {
    final String path = Uri.tryParse(location)?.path ?? location;
    if (!state.isEnabled(RemoteConfigKeys.newUserRegistrationEnabled) &&
        (path == AppRoutes.signUp || path.startsWith('${AppRoutes.signUp}/'))) {
      return AppRoutes.authWelcome;
    }
    if (!_isAuthenticatedPath(path)) {
      return null;
    }
    if (!state.isEnabled(RemoteConfigKeys.aiModulesEnabled) && _isAiPath(path)) {
      return AppRoutes.discover;
    }
    if (!state.isEnabled(RemoteConfigKeys.nearbyEnabled) && _isNearbyPath(path)) {
      return AppRoutes.discover;
    }
    if (!state.isEnabled(RemoteConfigKeys.marketplaceEnabled) &&
        _isMarketplacePath(path)) {
      return AppRoutes.discover;
    }
    if (!state.isEnabled(RemoteConfigKeys.messagingEnabled) &&
        _isMessagingPath(path)) {
      return AppRoutes.home;
    }
    if (!state.isEnabled(RemoteConfigKeys.storyUploadEnabled) &&
        path.startsWith('${AppRoutes.create}/story')) {
      return AppRoutes.create;
    }
    if (!state.isEnabled(RemoteConfigKeys.marketplaceEnabled) &&
        path.startsWith('${AppRoutes.create}/listing')) {
      return AppRoutes.create;
    }
    return null;
  }

  static bool showAiModules(ReleaseState state) =>
      state.isEnabled(RemoteConfigKeys.aiModulesEnabled);

  static bool showNearby(ReleaseState state) =>
      state.isEnabled(RemoteConfigKeys.nearbyEnabled);

  static bool showMarketplace(ReleaseState state) =>
      state.isEnabled(RemoteConfigKeys.marketplaceEnabled);

  static bool showMessaging(ReleaseState state) =>
      state.isEnabled(RemoteConfigKeys.messagingEnabled);

  static bool showStoryUpload(ReleaseState state) =>
      state.isEnabled(RemoteConfigKeys.storyUploadEnabled);

  static bool showRegistration(ReleaseState state) =>
      state.isEnabled(RemoteConfigKeys.newUserRegistrationEnabled);

  static bool _isAuthenticatedPath(String path) =>
      AppRoutes.isAuthenticatedLocation(path);

  static bool _isAiPath(String path) =>
      path == AppRoutes.aiHub || path.startsWith('${AppRoutes.aiHub}/');

  static bool _isNearbyPath(String path) =>
      path == AppRoutes.nearby || path.startsWith('${AppRoutes.nearby}/');

  static bool _isMarketplacePath(String path) =>
      path == AppRoutes.marketplace ||
      path.startsWith('${AppRoutes.marketplace}/') ||
      path == AppRoutes.myMarketplaceListings ||
      path.startsWith('${AppRoutes.myMarketplaceListings}/');

  static bool _isMessagingPath(String path) =>
      path == AppRoutes.messages ||
      path.startsWith('${AppRoutes.messages}/') ||
      path.startsWith('/messages/');
}

