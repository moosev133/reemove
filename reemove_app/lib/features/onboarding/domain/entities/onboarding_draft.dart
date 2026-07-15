import '../../../../core/domain/value_objects/content_policy.dart';
import '../../../../core/domain/value_objects/geo_location.dart';
import '../../../profile/domain/entities/user_profile.dart';

enum OnboardingStep {
  profile,
  birthday,
  sports,
  levels,
  goals,
  location,
  discovery,
  accessibility,
  notifications,
  review,
}

enum OnboardingProgressStatus { notStarted, inProgress, completed }

enum PermissionDecision {
  notAsked,
  granted,
  denied,
  deniedForever,
  unavailable,
}

enum NotificationPermissionDecision {
  notAsked,
  authorized,
  provisional,
  denied,
  unavailable,
}

class DiscoveryPreferences {
  const DiscoveryPreferences({
    this.radiusKm = 25,
    this.showNearbyPeople = true,
    this.recommendEvents = true,
    this.allowTrainerDiscovery = true,
    this.visibility = Visibility.public,
  });

  final double radiusKm;
  final bool showNearbyPeople;
  final bool recommendEvents;
  final bool allowTrainerDiscovery;
  final Visibility visibility;

  DiscoveryPreferences copyWith({
    double? radiusKm,
    bool? showNearbyPeople,
    bool? recommendEvents,
    bool? allowTrainerDiscovery,
    Visibility? visibility,
  }) {
    return DiscoveryPreferences(
      radiusKm: radiusKm ?? this.radiusKm,
      showNearbyPeople: showNearbyPeople ?? this.showNearbyPeople,
      recommendEvents: recommendEvents ?? this.recommendEvents,
      allowTrainerDiscovery:
          allowTrainerDiscovery ?? this.allowTrainerDiscovery,
      visibility: visibility ?? this.visibility,
    );
  }
}

class AccessibilityPreferences {
  const AccessibilityPreferences({
    this.reduceMotion = false,
    this.highContrast = false,
    this.largeText = false,
    this.screenReaderOptimized = false,
  });

  final bool reduceMotion;
  final bool highContrast;
  final bool largeText;
  final bool screenReaderOptimized;

  AccessibilityPreferences copyWith({
    bool? reduceMotion,
    bool? highContrast,
    bool? largeText,
    bool? screenReaderOptimized,
  }) {
    return AccessibilityPreferences(
      reduceMotion: reduceMotion ?? this.reduceMotion,
      highContrast: highContrast ?? this.highContrast,
      largeText: largeText ?? this.largeText,
      screenReaderOptimized:
          screenReaderOptimized ?? this.screenReaderOptimized,
    );
  }
}

class NotificationPreferences {
  const NotificationPreferences({
    this.masterEnabled = false,
    this.activity = true,
    this.messages = true,
    this.events = true,
    this.challenges = true,
    this.productUpdates = false,
    this.permissionStatus = NotificationPermissionDecision.notAsked,
  });

  final bool masterEnabled;
  final bool activity;
  final bool messages;
  final bool events;
  final bool challenges;
  final bool productUpdates;
  final NotificationPermissionDecision permissionStatus;

  NotificationPreferences copyWith({
    bool? masterEnabled,
    bool? activity,
    bool? messages,
    bool? events,
    bool? challenges,
    bool? productUpdates,
    NotificationPermissionDecision? permissionStatus,
  }) {
    return NotificationPreferences(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      activity: activity ?? this.activity,
      messages: messages ?? this.messages,
      events: events ?? this.events,
      challenges: challenges ?? this.challenges,
      productUpdates: productUpdates ?? this.productUpdates,
      permissionStatus: permissionStatus ?? this.permissionStatus,
    );
  }
}

class OnboardingDraft {
  const OnboardingDraft({
    required this.version,
    required this.currentStep,
    required this.favoriteSportIds,
    required this.sportLevels,
    required this.goals,
    required this.locationPermission,
    required this.discovery,
    required this.accessibility,
    required this.notifications,
    required this.status,
    this.dateOfBirth,
    this.avatarUrl,
    this.avatarStoragePath,
    this.location,
    this.updatedAt,
    this.completedAt,
  });

  factory OnboardingDraft.initial({String? avatarUrl}) => OnboardingDraft(
    version: 1,
    currentStep: OnboardingStep.profile,
    avatarUrl: avatarUrl,
    favoriteSportIds: const <String>[],
    sportLevels: const <String, SportLevel>{},
    goals: const <String>[],
    locationPermission: PermissionDecision.notAsked,
    discovery: const DiscoveryPreferences(),
    accessibility: const AccessibilityPreferences(),
    notifications: const NotificationPreferences(),
    status: OnboardingProgressStatus.notStarted,
  );

  final int version;
  final OnboardingStep currentStep;
  final DateTime? dateOfBirth;
  final String? avatarUrl;
  final String? avatarStoragePath;
  final List<String> favoriteSportIds;
  final Map<String, SportLevel> sportLevels;
  final List<String> goals;
  final GeoLocation? location;
  final PermissionDecision locationPermission;
  final DiscoveryPreferences discovery;
  final AccessibilityPreferences accessibility;
  final NotificationPreferences notifications;
  final OnboardingProgressStatus status;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  OnboardingDraft copyWith({
    int? version,
    OnboardingStep? currentStep,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    String? avatarStoragePath,
    bool clearAvatarStoragePath = false,
    List<String>? favoriteSportIds,
    Map<String, SportLevel>? sportLevels,
    List<String>? goals,
    GeoLocation? location,
    bool clearLocation = false,
    PermissionDecision? locationPermission,
    DiscoveryPreferences? discovery,
    AccessibilityPreferences? accessibility,
    NotificationPreferences? notifications,
    OnboardingProgressStatus? status,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return OnboardingDraft(
      version: version ?? this.version,
      currentStep: currentStep ?? this.currentStep,
      dateOfBirth: clearDateOfBirth ? null : dateOfBirth ?? this.dateOfBirth,
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
      avatarStoragePath: clearAvatarStoragePath
          ? null
          : avatarStoragePath ?? this.avatarStoragePath,
      favoriteSportIds: favoriteSportIds ?? this.favoriteSportIds,
      sportLevels: sportLevels ?? this.sportLevels,
      goals: goals ?? this.goals,
      location: clearLocation ? null : location ?? this.location,
      locationPermission: locationPermission ?? this.locationPermission,
      discovery: discovery ?? this.discovery,
      accessibility: accessibility ?? this.accessibility,
      notifications: notifications ?? this.notifications,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

extension OnboardingStepNavigation on OnboardingStep {
  OnboardingStep? get previous {
    final int index = OnboardingStep.values.indexOf(this);
    return index > 0 ? OnboardingStep.values[index - 1] : null;
  }

  OnboardingStep? get next {
    final int index = OnboardingStep.values.indexOf(this);
    return index < OnboardingStep.values.length - 1
        ? OnboardingStep.values[index + 1]
        : null;
  }
}
