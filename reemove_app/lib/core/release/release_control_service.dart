import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'release_state.dart';
import 'remote_config_keys.dart';

/// Loads release gates and feature flags from Remote Config.
///
/// Callers must only construct this when Firebase is ready. Prefer
/// [ReleaseControlService.loadSafeDefaults] when Firebase is unavailable.
class ReleaseControlService {
  ReleaseControlService(this._remoteConfig, {this.defaults = const {}});

  final FirebaseRemoteConfig _remoteConfig;
  final Map<String, Object> defaults;

  /// Safe offline defaults: features on, no maintenance, no forced update.
  static ReleaseState loadSafeDefaults({Uri? supportUrl, Uri? statusUrl}) {
    return ReleaseState(
      maintenanceMode: false,
      maintenanceTitle: 'ReeMove is temporarily unavailable',
      maintenanceMessage:
          'We are working to restore service. Please try again shortly.',
      updateRequirement: UpdateRequirement.none,
      featureFlags: <String, bool>{
        RemoteConfigKeys.aiModulesEnabled: true,
        RemoteConfigKeys.nearbyEnabled: true,
        RemoteConfigKeys.marketplaceEnabled: true,
        RemoteConfigKeys.messagingEnabled: true,
        RemoteConfigKeys.storyUploadEnabled: true,
        RemoteConfigKeys.newUserRegistrationEnabled: true,
      },
      supportUrl: supportUrl ?? Uri.parse('https://reemove.app/support'),
      statusUrl: statusUrl ?? Uri.parse('https://status.reemove.app'),
    );
  }

  Future<ReleaseState> load() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    if (defaults.isNotEmpty) {
      await _remoteConfig.setDefaults(defaults);
    }
    try {
      await _remoteConfig.fetchAndActivate();
    } on Object {
      // Keep previously activated / default values when fetch fails.
    }

    final PackageInfo package = await PackageInfo.fromPlatform();
    final int build = int.tryParse(package.buildNumber) ?? 0;
    final bool isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final int minimum = isIos
        ? _remoteConfig.getInt(RemoteConfigKeys.minimumSupportedIosBuild)
        : _remoteConfig.getInt(RemoteConfigKeys.minimumSupportedAndroidBuild);
    final int recommended = isIos
        ? _remoteConfig.getInt(RemoteConfigKeys.recommendedIosBuild)
        : _remoteConfig.getInt(RemoteConfigKeys.recommendedAndroidBuild);
    final bool forceUpdate = _remoteConfig.getBool(
      RemoteConfigKeys.forceUpdate,
    );

    final UpdateRequirement updateRequirement =
        build < minimum || (forceUpdate && build < recommended)
        ? UpdateRequirement.required
        : build < recommended
        ? UpdateRequirement.recommended
        : UpdateRequirement.none;

    return ReleaseState(
      maintenanceMode: _remoteConfig.getBool(RemoteConfigKeys.maintenanceMode),
      maintenanceTitle: _remoteConfig.getString(
        RemoteConfigKeys.maintenanceTitle,
      ),
      maintenanceMessage: _remoteConfig.getString(
        RemoteConfigKeys.maintenanceMessage,
      ),
      updateRequirement: updateRequirement,
      featureFlags: <String, bool>{
        RemoteConfigKeys.aiModulesEnabled: _remoteConfig.getBool(
          RemoteConfigKeys.aiModulesEnabled,
        ),
        RemoteConfigKeys.nearbyEnabled: _remoteConfig.getBool(
          RemoteConfigKeys.nearbyEnabled,
        ),
        RemoteConfigKeys.marketplaceEnabled: _remoteConfig.getBool(
          RemoteConfigKeys.marketplaceEnabled,
        ),
        RemoteConfigKeys.messagingEnabled: _remoteConfig.getBool(
          RemoteConfigKeys.messagingEnabled,
        ),
        RemoteConfigKeys.storyUploadEnabled: _remoteConfig.getBool(
          RemoteConfigKeys.storyUploadEnabled,
        ),
        RemoteConfigKeys.newUserRegistrationEnabled: _remoteConfig.getBool(
          RemoteConfigKeys.newUserRegistrationEnabled,
        ),
      },
      supportUrl: _parseUri(
        _remoteConfig.getString(RemoteConfigKeys.supportUrl),
        fallback: Uri.parse('https://reemove.app/support'),
      ),
      statusUrl: _parseUri(
        _remoteConfig.getString(RemoteConfigKeys.statusUrl),
        fallback: Uri.parse('https://status.reemove.app'),
      ),
    );
  }

  Uri _parseUri(String value, {required Uri fallback}) {
    final Uri? parsed = Uri.tryParse(value.trim());
    if (parsed == null || !(parsed.hasScheme && parsed.hasAuthority)) {
      return fallback;
    }
    return parsed;
  }
}
