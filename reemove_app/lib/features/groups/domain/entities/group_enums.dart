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

/// Group-owned conversation channel types.
enum GroupChannelType { memberChat, announcements }

/// Media delivery contract for a group channel.
///
/// Phase C1 only publishes these contracts to clients; genuine
/// disappearing / view-once media behavior (auto-delete timers, screenshot
/// detection, forwarding restrictions, etc.) ships in Phase C2. Until then
/// `viewOnce` must be treated as unsupported even when a contract lists it.
enum GroupMediaMode { normal, keepInChat, viewOnce }

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

GroupPrivacy parseGroupPrivacy(Object? value, {GroupPrivacy fallback = GroupPrivacy.public}) {
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

GroupStatus parseGroupStatus(Object? value, {GroupStatus fallback = GroupStatus.active}) {
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
