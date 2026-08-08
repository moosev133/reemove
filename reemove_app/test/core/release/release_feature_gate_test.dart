import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/release/release_feature_gate.dart';
import 'package:reemove/core/release/release_state.dart';
import 'package:reemove/core/release/remote_config_keys.dart';

ReleaseState _state({required Map<String, bool> flags}) => ReleaseState(
  maintenanceMode: false,
  maintenanceTitle: '',
  maintenanceMessage: '',
  updateRequirement: UpdateRequirement.none,
  featureFlags: flags,
  supportUrl: Uri.parse('https://reemove.app/support'),
  statusUrl: Uri.parse('https://status.reemove.app'),
);

void main() {
  test('redirects disabled AI routes to discover', () {
    final ReleaseState state = _state(
      flags: <String, bool>{RemoteConfigKeys.aiModulesEnabled: false},
    );
    expect(
      ReleaseFeatureGate.redirectForLocation('/discover/ai/coach', state),
      '/discover',
    );
  });

  test('redirects disabled messaging to home', () {
    final ReleaseState state = _state(
      flags: <String, bool>{RemoteConfigKeys.messagingEnabled: false},
    );
    expect(
      ReleaseFeatureGate.redirectForLocation('/messages/c1', state),
      '/home',
    );
  });

  test('redirects disabled sign-up to auth welcome', () {
    final ReleaseState state = _state(
      flags: <String, bool>{
        RemoteConfigKeys.newUserRegistrationEnabled: false,
      },
    );
    expect(
      ReleaseFeatureGate.redirectForLocation('/auth/sign-up', state),
      '/auth',
    );
  });
}

