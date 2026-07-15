import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import '../firebase/firebase_bootstrap.dart';
import '../providers/core_providers.dart';
import 'release_control_service.dart';
import 'release_state.dart';
import 'remote_config_keys.dart';

/// Shared release gates / feature flags for the whole app.
///
/// Falls back to safe local defaults when Firebase is unavailable so the
/// Phase 1–15 graceful bootstrap path remains intact.
final FutureProvider<ReleaseState> releaseStateProvider =
    FutureProvider<ReleaseState>((Ref ref) async {
      final FirebaseBootstrapReport report = ref.watch(
        firebaseBootstrapReportProvider,
      );
      final AppEnvironment environment = ref.watch(appEnvironmentProvider);
      final Uri? supportUrl = _tryParse(environment.supportUrl);
      final Uri? statusUrl = _tryParse(environment.statusUrl);

      if (!report.isReady) {
        return ReleaseControlService.loadSafeDefaults(
          supportUrl: supportUrl,
          statusUrl: statusUrl,
        );
      }

      try {
        final ReleaseControlService service = ReleaseControlService(
          FirebaseRemoteConfig.instance,
          defaults: _builtInDefaults(environment),
        );
        return await service.load();
      } on Object {
        return ReleaseControlService.loadSafeDefaults(
          supportUrl: supportUrl,
          statusUrl: statusUrl,
        );
      }
    });

Uri? _tryParse(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return Uri.tryParse(value.trim());
}

Map<String, Object> _builtInDefaults(AppEnvironment environment) {
  return <String, Object>{
    RemoteConfigKeys.maintenanceMode: false,
    RemoteConfigKeys.maintenanceTitle: 'ReeMove is temporarily unavailable',
    RemoteConfigKeys.maintenanceMessage:
        'We are working to restore service. Please try again shortly.',
    RemoteConfigKeys.minimumSupportedAndroidBuild: 1,
    RemoteConfigKeys.minimumSupportedIosBuild: 1,
    RemoteConfigKeys.recommendedAndroidBuild: 1,
    RemoteConfigKeys.recommendedIosBuild: 1,
    RemoteConfigKeys.forceUpdate: false,
    RemoteConfigKeys.aiModulesEnabled: true,
    RemoteConfigKeys.nearbyEnabled: true,
    RemoteConfigKeys.marketplaceEnabled: true,
    RemoteConfigKeys.messagingEnabled: true,
    RemoteConfigKeys.storyUploadEnabled: true,
    RemoteConfigKeys.newUserRegistrationEnabled: true,
    RemoteConfigKeys.supportUrl:
        environment.supportUrl ?? 'https://reemove.app/support',
    RemoteConfigKeys.statusUrl:
        environment.statusUrl ?? 'https://status.reemove.app',
  };
}
