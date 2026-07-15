enum UpdateRequirement { none, recommended, required }

class ReleaseState {
  const ReleaseState({
    required this.maintenanceMode,
    required this.maintenanceTitle,
    required this.maintenanceMessage,
    required this.updateRequirement,
    required this.featureFlags,
    required this.supportUrl,
    required this.statusUrl,
  });

  final bool maintenanceMode;
  final String maintenanceTitle;
  final String maintenanceMessage;
  final UpdateRequirement updateRequirement;
  final Map<String, bool> featureFlags;
  final Uri supportUrl;
  final Uri statusUrl;

  bool isEnabled(String key) => featureFlags[key] ?? false;
}
