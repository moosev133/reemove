class GroupNotificationPreferences {
  const GroupNotificationPreferences({
    this.muted = false,
    this.memberChatEnabled = true,
    this.announcementsEnabled = true,
    this.sessionsEnabled = true,
    this.invitationsEnabled = true,
  });

  final bool muted;
  final bool memberChatEnabled;
  final bool announcementsEnabled;
  final bool sessionsEnabled;
  final bool invitationsEnabled;

  GroupNotificationPreferences copyWith({
    bool? muted,
    bool? memberChatEnabled,
    bool? announcementsEnabled,
    bool? sessionsEnabled,
    bool? invitationsEnabled,
  }) {
    return GroupNotificationPreferences(
      muted: muted ?? this.muted,
      memberChatEnabled: memberChatEnabled ?? this.memberChatEnabled,
      announcementsEnabled: announcementsEnabled ?? this.announcementsEnabled,
      sessionsEnabled: sessionsEnabled ?? this.sessionsEnabled,
      invitationsEnabled: invitationsEnabled ?? this.invitationsEnabled,
    );
  }

  Map<String, Object?> toCallableJson() => <String, Object?>{
        'muted': muted,
        'memberChatEnabled': memberChatEnabled,
        'announcementsEnabled': announcementsEnabled,
        'sessionsEnabled': sessionsEnabled,
        'invitationsEnabled': invitationsEnabled,
      };

  static GroupNotificationPreferences fromCallableJson(
    Map<String, Object?> json,
  ) {
    bool boolValue(String key, bool fallback) {
      final Object? value = json[key];
      return value is bool ? value : fallback;
    }

    return GroupNotificationPreferences(
      muted: boolValue('muted', false),
      memberChatEnabled: boolValue('memberChatEnabled', true),
      announcementsEnabled: boolValue('announcementsEnabled', true),
      sessionsEnabled: boolValue('sessionsEnabled', true),
      invitationsEnabled: boolValue('invitationsEnabled', true),
    );
  }
}


