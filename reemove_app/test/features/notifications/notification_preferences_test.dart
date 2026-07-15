import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/notifications/domain/entities/notification_preferences.dart';

void main() {
  test(
    'serializes all unified notification controls for callable functions',
    () {
      const UnifiedNotificationPreferences preferences =
          UnifiedNotificationPreferences(
            masterEnabled: true,
            showPreviews: false,
            activity: true,
            messages: false,
            events: true,
            challenges: true,
            marketplace: false,
            system: true,
            productUpdates: false,
            quietHours: NotificationQuietHours(
              enabled: true,
              startMinutes: 1320,
              endMinutes: 420,
              utcOffsetMinutes: 180,
            ),
          );

      final Map<String, Object?> json = preferences.toCallableJson();
      final Map<String, Object?> quiet =
          json['quietHours']! as Map<String, Object?>;

      expect(json['masterEnabled'], isTrue);
      expect(json['showPreviews'], isFalse);
      expect(json['messages'], isFalse);
      expect(json['marketplace'], isFalse);
      expect(quiet['enabled'], isTrue);
      expect(quiet['startMinutes'], 1320);
      expect(quiet['endMinutes'], 420);
      expect(quiet['utcOffsetMinutes'], 180);
    },
  );

  test('copyWith preserves untouched category choices', () {
    const UnifiedNotificationPreferences initial =
        UnifiedNotificationPreferences(messages: false, marketplace: false);

    final UnifiedNotificationPreferences updated = initial.copyWith(
      masterEnabled: true,
      events: false,
    );

    expect(updated.masterEnabled, isTrue);
    expect(updated.events, isFalse);
    expect(updated.messages, isFalse);
    expect(updated.marketplace, isFalse);
    expect(updated.activity, isTrue);
  });
}
