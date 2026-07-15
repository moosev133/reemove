class NotificationQuietHours {
  const NotificationQuietHours({
    this.enabled = false,
    this.startMinutes = 22 * 60,
    this.endMinutes = 7 * 60,
    this.utcOffsetMinutes = 0,
  });

  final bool enabled;
  final int startMinutes;
  final int endMinutes;
  final int utcOffsetMinutes;

  NotificationQuietHours copyWith({
    bool? enabled,
    int? startMinutes,
    int? endMinutes,
    int? utcOffsetMinutes,
  }) {
    return NotificationQuietHours(
      enabled: enabled ?? this.enabled,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      utcOffsetMinutes: utcOffsetMinutes ?? this.utcOffsetMinutes,
    );
  }
}

class UnifiedNotificationPreferences {
  const UnifiedNotificationPreferences({
    this.masterEnabled = false,
    this.showPreviews = true,
    this.activity = true,
    this.messages = true,
    this.events = true,
    this.challenges = true,
    this.marketplace = true,
    this.system = true,
    this.productUpdates = false,
    this.quietHours = const NotificationQuietHours(),
  });

  final bool masterEnabled;
  final bool showPreviews;
  final bool activity;
  final bool messages;
  final bool events;
  final bool challenges;
  final bool marketplace;
  final bool system;
  final bool productUpdates;
  final NotificationQuietHours quietHours;

  UnifiedNotificationPreferences copyWith({
    bool? masterEnabled,
    bool? showPreviews,
    bool? activity,
    bool? messages,
    bool? events,
    bool? challenges,
    bool? marketplace,
    bool? system,
    bool? productUpdates,
    NotificationQuietHours? quietHours,
  }) {
    return UnifiedNotificationPreferences(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      showPreviews: showPreviews ?? this.showPreviews,
      activity: activity ?? this.activity,
      messages: messages ?? this.messages,
      events: events ?? this.events,
      challenges: challenges ?? this.challenges,
      marketplace: marketplace ?? this.marketplace,
      system: system ?? this.system,
      productUpdates: productUpdates ?? this.productUpdates,
      quietHours: quietHours ?? this.quietHours,
    );
  }

  Map<String, Object?> toCallableJson() => <String, Object?>{
    'masterEnabled': masterEnabled,
    'showPreviews': showPreviews,
    'activity': activity,
    'messages': messages,
    'events': events,
    'challenges': challenges,
    'marketplace': marketplace,
    'system': system,
    'productUpdates': productUpdates,
    'quietHours': <String, Object?>{
      'enabled': quietHours.enabled,
      'startMinutes': quietHours.startMinutes,
      'endMinutes': quietHours.endMinutes,
      'utcOffsetMinutes': quietHours.utcOffsetMinutes,
    },
  };
}
