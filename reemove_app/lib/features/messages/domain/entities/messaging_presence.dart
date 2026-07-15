enum MessagingPresenceState { offline, away, online }

class MessagingPresence {
  const MessagingPresence({
    required this.userId,
    required this.state,
    required this.lastChanged,
  });

  final String userId;
  final MessagingPresenceState state;
  final DateTime lastChanged;
}

class TypingParticipant {
  const TypingParticipant({
    required this.userId,
    required this.isTyping,
    required this.updatedAt,
  });

  final String userId;
  final bool isTyping;
  final DateTime updatedAt;
}
