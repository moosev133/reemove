/// Visibility of a group in discovery and to non-members.
enum GroupPrivacy { public, private, hidden }

/// How a prospective member may join a group.
enum GroupJoinPolicy { open, approvalRequired, inviteOnly }

/// A member's standing within a group's roster.
enum GroupMemberRole { owner, admin, member }

/// Lifecycle state of a group document.
enum GroupStatus { active, archived, deleted }

/// Lifecycle state of a scheduled group session.
enum GroupSessionStatus { scheduled, cancelled, completed }

/// Typed schedule kinds (training / match / event).
enum GroupSessionType { training, match, event }

/// Member RSVP for a scheduled group session.
enum GroupSessionRsvpStatus { going, maybe, notGoing }

/// Group-owned conversation channel types.
enum GroupChannelType { memberChat, announcements }

/// Media delivery contract for a group channel.
///
/// View-once open/claim is enforced server-side. Screenshot prevention cannot
/// be guaranteed on every platform.
enum GroupMediaMode { normal, keepInChat, viewOnce }

extension GroupChannelTypeWire on GroupChannelType {
  String get wireValue => switch (this) {
    GroupChannelType.memberChat => 'member_chat',
    GroupChannelType.announcements => 'announcements',
  };

  String get displayLabel => switch (this) {
    GroupChannelType.memberChat => 'Member chat',
    GroupChannelType.announcements => 'Announcements',
  };
}

extension GroupMediaModeWire on GroupMediaMode {
  String get wireValue => switch (this) {
    GroupMediaMode.normal => 'normal',
    GroupMediaMode.keepInChat => 'keep_in_chat',
    GroupMediaMode.viewOnce => 'view_once',
  };

  String get displayLabel => switch (this) {
    GroupMediaMode.normal => 'Normal',
    GroupMediaMode.keepInChat => 'Keep in chat',
    GroupMediaMode.viewOnce => 'View once',
  };
}

/// The viewer's relationship to a group, combining an active membership
/// role with the non-member states surfaced by `getGroup`.
enum GroupMembershipStatus { none, pending, member, admin, owner }

extension GroupMemberRoleParsing on GroupMemberRole {
  String get wireValue => name;
}

GroupMemberRole? tryParseGroupMemberRole(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  for (final GroupMemberRole role in GroupMemberRole.values) {
    if (role.name == value) {
      return role;
    }
  }
  return null;
}

GroupPrivacy parseGroupPrivacy(
  Object? value, {
  GroupPrivacy fallback = GroupPrivacy.public,
}) {
  for (final GroupPrivacy privacy in GroupPrivacy.values) {
    if (privacy.name == value) {
      return privacy;
    }
  }
  return fallback;
}

GroupJoinPolicy parseGroupJoinPolicy(
  Object? value, {
  GroupJoinPolicy fallback = GroupJoinPolicy.approvalRequired,
}) {
  for (final GroupJoinPolicy policy in GroupJoinPolicy.values) {
    if (policy.name == value) {
      return policy;
    }
  }
  return fallback;
}

GroupStatus parseGroupStatus(
  Object? value, {
  GroupStatus fallback = GroupStatus.active,
}) {
  for (final GroupStatus status in GroupStatus.values) {
    if (status.name == value) {
      return status;
    }
  }
  return fallback;
}

GroupSessionStatus parseGroupSessionStatus(
  Object? value, {
  GroupSessionStatus fallback = GroupSessionStatus.scheduled,
}) {
  for (final GroupSessionStatus status in GroupSessionStatus.values) {
    if (status.name == value) {
      return status;
    }
  }
  return fallback;
}

GroupSessionType parseGroupSessionType(
  Object? value, {
  GroupSessionType fallback = GroupSessionType.event,
}) {
  return switch (value) {
    'training' => GroupSessionType.training,
    'match' => GroupSessionType.match,
    'event' => GroupSessionType.event,
    _ => fallback,
  };
}

GroupSessionRsvpStatus? tryParseGroupSessionRsvpStatus(Object? value) {
  return switch (value) {
    'going' => GroupSessionRsvpStatus.going,
    'maybe' => GroupSessionRsvpStatus.maybe,
    'not_going' => GroupSessionRsvpStatus.notGoing,
    _ => null,
  };
}

extension GroupSessionTypeWire on GroupSessionType {
  String get wireValue => name;

  String get displayLabel => switch (this) {
    GroupSessionType.training => 'Training',
    GroupSessionType.match => 'Match',
    GroupSessionType.event => 'Event',
  };
}

extension GroupSessionRsvpStatusWire on GroupSessionRsvpStatus {
  String get wireValue => switch (this) {
    GroupSessionRsvpStatus.going => 'going',
    GroupSessionRsvpStatus.maybe => 'maybe',
    GroupSessionRsvpStatus.notGoing => 'not_going',
  };

  String get displayLabel => switch (this) {
    GroupSessionRsvpStatus.going => 'Going',
    GroupSessionRsvpStatus.maybe => 'Maybe',
    GroupSessionRsvpStatus.notGoing => 'Can\'t go',
  };
}

GroupMembershipStatus parseGroupMembershipStatus(Object? value) {
  for (final GroupMembershipStatus status in GroupMembershipStatus.values) {
    if (status.name == value) {
      return status;
    }
  }
  return GroupMembershipStatus.none;
}

GroupChannelType parseGroupChannelType(Object? value) => switch (value) {
  'announcements' => GroupChannelType.announcements,
  _ => GroupChannelType.memberChat,
};

GroupMediaMode parseGroupMediaMode(Object? value) => switch (value) {
  'keep_in_chat' => GroupMediaMode.keepInChat,
  'view_once' => GroupMediaMode.viewOnce,
  _ => GroupMediaMode.normal,
};
