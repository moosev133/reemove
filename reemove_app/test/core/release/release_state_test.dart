import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/release/release_control_service.dart';
import 'package:reemove/core/release/release_state.dart';
import 'package:reemove/core/release/remote_config_keys.dart';

UpdateRequirement resolveUpdateRequirement({
  required int build,
  required int minimum,
  required int recommended,
  required bool forceUpdate,
}) {
  if (build < minimum || (forceUpdate && build < recommended)) {
    return UpdateRequirement.required;
  }
  if (build < recommended) {
    return UpdateRequirement.recommended;
  }
  return UpdateRequirement.none;
}

void main() {
  test('required update takes precedence over recommended update', () {
    expect(
      resolveUpdateRequirement(
        build: 9,
        minimum: 10,
        recommended: 12,
        forceUpdate: false,
      ),
      UpdateRequirement.required,
    );
    expect(
      resolveUpdateRequirement(
        build: 11,
        minimum: 10,
        recommended: 12,
        forceUpdate: true,
      ),
      UpdateRequirement.required,
    );
    expect(
      resolveUpdateRequirement(
        build: 11,
        minimum: 10,
        recommended: 12,
        forceUpdate: false,
      ),
      UpdateRequirement.recommended,
    );
  });

  test('missing feature flag fails closed', () {
    final ReleaseState state = ReleaseState(
      maintenanceMode: false,
      maintenanceTitle: 't',
      maintenanceMessage: 'm',
      updateRequirement: UpdateRequirement.none,
      featureFlags: const <String, bool>{},
      supportUrl: Uri.parse('https://reemove.app/support'),
      statusUrl: Uri.parse('https://status.reemove.app'),
    );
    expect(state.isEnabled('unknown'), isFalse);
    expect(state.isEnabled(RemoteConfigKeys.aiModulesEnabled), isFalse);
  });

  test('safe defaults keep features enabled without Firebase', () {
    final ReleaseState state = ReleaseControlService.loadSafeDefaults();
    expect(state.maintenanceMode, isFalse);
    expect(state.updateRequirement, UpdateRequirement.none);
    expect(state.isEnabled(RemoteConfigKeys.aiModulesEnabled), isTrue);
    expect(state.isEnabled(RemoteConfigKeys.marketplaceEnabled), isTrue);
  });
}
