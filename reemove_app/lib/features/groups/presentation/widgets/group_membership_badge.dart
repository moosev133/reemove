import 'package:flutter/material.dart';

import '../../../../core/widgets/app_status_chip.dart';
import '../../domain/entities/group_enums.dart';

/// Small status chip summarizing the viewer's relationship to a group.
class GroupMembershipBadge extends StatelessWidget {
  const GroupMembershipBadge({required this.status, super.key});

  final GroupMembershipStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return switch (status) {
      GroupMembershipStatus.owner => AppStatusChip(
        label: 'Owner',
        icon: Icons.workspace_premium_rounded,
        color: colors.primary,
      ),
      GroupMembershipStatus.admin => AppStatusChip(
        label: 'Admin',
        icon: Icons.admin_panel_settings_outlined,
        color: colors.primary,
      ),
      GroupMembershipStatus.member => AppStatusChip(
        label: 'Member',
        icon: Icons.check_circle_outline_rounded,
        color: colors.tertiary,
      ),
      GroupMembershipStatus.pending => AppStatusChip(
        label: 'Pending',
        icon: Icons.hourglass_top_rounded,
        color: colors.secondary,
      ),
      GroupMembershipStatus.none => const SizedBox.shrink(),
    };
  }
}

String groupPrivacyLabel(GroupPrivacy privacy) => switch (privacy) {
  GroupPrivacy.public => 'Public',
  GroupPrivacy.private => 'Private',
  GroupPrivacy.hidden => 'Hidden',
};

String groupJoinPolicyLabel(GroupJoinPolicy policy) => switch (policy) {
  GroupJoinPolicy.open => 'Open to join',
  GroupJoinPolicy.approvalRequired => 'Approval required',
  GroupJoinPolicy.inviteOnly => 'Invite only',
};

String groupMemberRoleLabel(GroupMemberRole role) => switch (role) {
  GroupMemberRole.owner => 'Owner',
  GroupMemberRole.admin => 'Admin',
  GroupMemberRole.member => 'Member',
};

IconData groupPrivacyIcon(GroupPrivacy privacy) => switch (privacy) {
  GroupPrivacy.public => Icons.public_rounded,
  GroupPrivacy.private => Icons.lock_outline_rounded,
  GroupPrivacy.hidden => Icons.visibility_off_outlined,
};
