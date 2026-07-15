import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/firestore_parser.dart';
import '../../../../core/domain/value_objects/content_policy.dart';
import '../../../../core/domain/value_objects/geo_location.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../domain/entities/onboarding_draft.dart';

class OnboardingDraftDto {
  const OnboardingDraftDto(this.value);

  factory OnboardingDraftDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Onboarding document ${snapshot.id} has no data.');
    }
    return OnboardingDraftDto.fromMap(data);
  }

  factory OnboardingDraftDto.fromMap(Map<String, dynamic> data) {
    return OnboardingDraftDto(
      OnboardingDraft(
        version: FirestoreParser.integer(data, 'version', fallback: 1),
        currentStep: _enumByName(
          OnboardingStep.values,
          FirestoreParser.string(data, 'currentStep', fallback: 'profile'),
          OnboardingStep.profile,
        ),
        dateOfBirth: _parseBirthDate(data['dateOfBirth']),
        avatarUrl: FirestoreParser.nullableString(data, 'avatarUrl'),
        avatarStoragePath: FirestoreParser.nullableString(
          data,
          'avatarStoragePath',
        ),
        favoriteSportIds: FirestoreParser.stringList(data, 'favoriteSportIds'),
        sportLevels: FirestoreParser.stringMap(data, 'sportLevels').map(
          (String sportId, String level) => MapEntry<String, SportLevel>(
            sportId,
            _enumByName(SportLevel.values, level, SportLevel.beginner),
          ),
        ),
        goals: FirestoreParser.stringList(data, 'goals'),
        location: _parseLocation(data['location']),
        locationPermission: _enumByName(
          PermissionDecision.values,
          FirestoreParser.string(
            data,
            'locationPermission',
            fallback: 'notAsked',
          ),
          PermissionDecision.notAsked,
        ),
        discovery: _parseDiscovery(data['discovery']),
        accessibility: _parseAccessibility(data['accessibility']),
        notifications: _parseNotifications(data['notifications']),
        status: _parseStatus(
          FirestoreParser.string(data, 'status', fallback: 'not_started'),
        ),
        updatedAt: FirestoreParser.nullableDateTime(data, 'updatedAt'),
        completedAt: FirestoreParser.nullableDateTime(data, 'completedAt'),
      ),
    );
  }

  final OnboardingDraft value;

  Map<String, Object?> toRequestMap() => <String, Object?>{
    'version': value.version,
    'currentStep': value.currentStep.name,
    'dateOfBirth': value.dateOfBirth == null
        ? null
        : _formatBirthDate(value.dateOfBirth!),
    'avatarUrl': value.avatarUrl,
    'avatarStoragePath': value.avatarStoragePath,
    'favoriteSportIds': value.favoriteSportIds,
    'sportLevels': value.sportLevels.map(
      (String sportId, SportLevel level) =>
          MapEntry<String, String>(sportId, level.name),
    ),
    'goals': value.goals,
    'location': value.location == null
        ? null
        : <String, Object?>{
            'latitude': value.location!.latitude,
            'longitude': value.location!.longitude,
            if (value.location!.locality != null)
              'locality': value.location!.locality,
            if (value.location!.administrativeArea != null)
              'administrativeArea': value.location!.administrativeArea,
            if (value.location!.countryCode != null)
              'countryCode': value.location!.countryCode,
          },
    'locationPermission': value.locationPermission.name,
    'discovery': <String, Object?>{
      'radiusKm': value.discovery.radiusKm,
      'showNearbyPeople': value.discovery.showNearbyPeople,
      'recommendEvents': value.discovery.recommendEvents,
      'allowTrainerDiscovery': value.discovery.allowTrainerDiscovery,
      'visibility': value.discovery.visibility.storageValue,
    },
    'accessibility': <String, Object?>{
      'reduceMotion': value.accessibility.reduceMotion,
      'highContrast': value.accessibility.highContrast,
      'largeText': value.accessibility.largeText,
      'screenReaderOptimized': value.accessibility.screenReaderOptimized,
    },
    'notifications': <String, Object?>{
      'masterEnabled': value.notifications.masterEnabled,
      'activity': value.notifications.activity,
      'messages': value.notifications.messages,
      'events': value.notifications.events,
      'challenges': value.notifications.challenges,
      'productUpdates': value.notifications.productUpdates,
      'permissionStatus': value.notifications.permissionStatus.name,
    },
  };

  static T _enumByName<T extends Enum>(
    List<T> values,
    String name,
    T fallback,
  ) {
    for (final T value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return fallback;
  }

  static DateTime? _parseBirthDate(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw const FormatException('Expected birthday as YYYY-MM-DD.');
    }
    final DateTime? parsed = DateTime.tryParse('${value}T00:00:00.000Z');
    if (parsed == null) {
      throw const FormatException('Invalid birthday.');
    }
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }

  static String _formatBirthDate(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static GeoLocation? _parseLocation(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! Map) {
      throw const FormatException('Invalid onboarding location.');
    }
    final Map<String, dynamic> data = Map<String, dynamic>.from(value);
    final Object? latitude = data['latitude'];
    final Object? longitude = data['longitude'];
    if (latitude is! num || longitude is! num) {
      throw const FormatException('Invalid onboarding coordinates.');
    }
    return GeoLocation(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      geohash: data['geohash'] is String
          ? data['geohash'] as String
          : 'pending',
      locality: data['locality'] as String?,
      administrativeArea: data['administrativeArea'] as String?,
      countryCode: data['countryCode'] as String?,
    );
  }

  static DiscoveryPreferences _parseDiscovery(Object? value) {
    final Map<String, dynamic> data = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    final Object? radius = data['radiusKm'];
    return DiscoveryPreferences(
      radiusKm: radius is num ? radius.toDouble() : 25,
      showNearbyPeople: data['showNearbyPeople'] is bool
          ? data['showNearbyPeople'] as bool
          : true,
      recommendEvents: data['recommendEvents'] is bool
          ? data['recommendEvents'] as bool
          : true,
      allowTrainerDiscovery: data['allowTrainerDiscovery'] is bool
          ? data['allowTrainerDiscovery'] as bool
          : true,
      visibility: data['visibility'] is String
          ? VisibilityStorageValue.fromStorage(data['visibility'] as String)
          : Visibility.public,
    );
  }

  static AccessibilityPreferences _parseAccessibility(Object? value) {
    final Map<String, dynamic> data = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    return AccessibilityPreferences(
      reduceMotion: data['reduceMotion'] == true,
      highContrast: data['highContrast'] == true,
      largeText: data['largeText'] == true,
      screenReaderOptimized: data['screenReaderOptimized'] == true,
    );
  }

  static NotificationPreferences _parseNotifications(Object? value) {
    final Map<String, dynamic> data = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    return NotificationPreferences(
      masterEnabled: data['masterEnabled'] == true,
      activity: data['activity'] is bool ? data['activity'] as bool : true,
      messages: data['messages'] is bool ? data['messages'] as bool : true,
      events: data['events'] is bool ? data['events'] as bool : true,
      challenges: data['challenges'] is bool
          ? data['challenges'] as bool
          : true,
      productUpdates: data['productUpdates'] == true,
      permissionStatus: _enumByName(
        NotificationPermissionDecision.values,
        data['permissionStatus'] is String
            ? data['permissionStatus'] as String
            : 'notAsked',
        NotificationPermissionDecision.notAsked,
      ),
    );
  }

  static OnboardingProgressStatus _parseStatus(String value) {
    return switch (value) {
      'in_progress' => OnboardingProgressStatus.inProgress,
      'completed' => OnboardingProgressStatus.completed,
      _ => OnboardingProgressStatus.notStarted,
    };
  }
}
