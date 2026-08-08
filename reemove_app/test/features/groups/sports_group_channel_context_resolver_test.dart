import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/groups/application/sports_group_channel_context_resolver.dart';
import 'package:reemove/features/groups/domain/entities/group.dart';
import 'package:reemove/features/groups/domain/entities/group_channel.dart';
import 'package:reemove/features/groups/domain/entities/group_enums.dart';
import 'package:reemove/features/groups/domain/entities/group_location.dart';
import 'package:reemove/features/groups/domain/entities/sports_group_channel_context.dart';
import 'package:reemove/features/messages/domain/entities/conversation.dart';
import 'package:reemove/features/messages/domain/entities/messaging_user.dart';

Group _ownerGroup({String ownerId = 'owner-a'}) {
  return Group(
    groupId: 'g1',
    name: 'Trail Crew',
    description: 'Runs',
    category: 'running',
    privacy: GroupPrivacy.public,
    joinPolicy: GroupJoinPolicy.open,
    status: GroupStatus.active,
    memberCount: 2,
    capacity: 20,
    ownerId: ownerId,
    location: GroupLocation.empty,
    membershipStatus: GroupMembershipStatus.owner,
    viewerRole: GroupMemberRole.owner,
  );
}

Conversation _sportsConversation({required String viewerUid}) {
  return Conversation(
    id: 'c-member',
    type: ConversationType.group,
    title: 'Trail Crew',
    createdBy: 'owner-a',
    members: <ConversationMember>[
      ConversationMember(
        user: MessagingUser(
          id: viewerUid,
          displayName: 'Owner',
          username: 'owner',
          isVerified: false,
        ),
        role: ConversationMemberRole.owner,
        joinedAt: DateTime.utc(2026, 1, 1),
        notificationsEnabled: true,
        unreadCount: 0,
      ),
      ConversationMember(
        user: const MessagingUser(
          id: 'member-b',
          displayName: 'Member',
          username: 'member',
          isVerified: false,
        ),
        role: ConversationMemberRole.member,
        joinedAt: DateTime.utc(2026, 1, 1),
        notificationsEnabled: true,
        unreadCount: 0,
      ),
    ],
    memberCount: 2,
    moderationState: 'active',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    source: SportsGroupChannelContext.sourceValue,
    sportsGroupId: 'g1',
    sportsChannelType: 'member_chat',
  );
}

const List<GroupChannel> _channels = <GroupChannel>[
  GroupChannel(
    channelId: 'member_chat',
    type: GroupChannelType.memberChat,
    conversationId: 'c-member',
    supportedMediaModes: <GroupMediaMode>[GroupMediaMode.normal],
    publishRoles: <GroupMemberRole>[
      GroupMemberRole.owner,
      GroupMemberRole.admin,
      GroupMemberRole.member,
    ],
    readRoles: <GroupMemberRole>[
      GroupMemberRole.owner,
      GroupMemberRole.admin,
      GroupMemberRole.member,
    ],
  ),
];

void main() {
  group('SportsGroupChannelContextResolver', () {
    test('uses live group membership for canModerate', () {
      final SportsGroupChannelContext? resolved =
          SportsGroupChannelContextResolver.resolve(
            navigationContext: const SportsGroupChannelContext(
              groupId: 'g1',
              groupName: 'Trail Crew',
              channelType: GroupChannelType.memberChat,
              canPublish: true,
              canModerate: false,
              supportedMediaModes: <GroupMediaMode>[GroupMediaMode.normal],
              viewOnceSupported: false,
            ),
            conversation: _sportsConversation(viewerUid: 'owner-a'),
            group: _ownerGroup(),
            channel: _channels.first,
            viewerUid: 'owner-a',
          );

      expect(resolved?.canModerate, isTrue);
    });

    test('preserves navigation canModerate when group snapshot is stale', () {
      const Group staleGroup = Group(
        groupId: 'g1',
        name: 'Trail Crew',
        description: 'Runs',
        category: 'running',
        privacy: GroupPrivacy.public,
        joinPolicy: GroupJoinPolicy.open,
        status: GroupStatus.active,
        memberCount: 2,
        capacity: 20,
        ownerId: 'owner-a',
        location: GroupLocation.empty,
        membershipStatus: GroupMembershipStatus.member,
        viewerRole: GroupMemberRole.member,
      );

      final SportsGroupChannelContext? resolved =
          SportsGroupChannelContextResolver.resolve(
            navigationContext: const SportsGroupChannelContext(
              groupId: 'g1',
              groupName: 'Trail Crew',
              channelType: GroupChannelType.memberChat,
              canPublish: true,
              canModerate: true,
              supportedMediaModes: <GroupMediaMode>[GroupMediaMode.normal],
              viewOnceSupported: false,
            ),
            conversation: _sportsConversation(viewerUid: 'owner-a'),
            group: staleGroup,
            channel: _channels.first,
            viewerUid: 'owner-a',
          );

      expect(resolved?.canModerate, isTrue);
    });

    test('sports conversation creator can moderate before group loads', () {
      final SportsGroupChannelContext? resolved =
          SportsGroupChannelContextResolver.resolve(
            navigationContext: null,
            conversation: _sportsConversation(viewerUid: 'owner-a'),
            group: null,
            channel: null,
            viewerUid: 'owner-a',
          );

      expect(resolved?.canModerate, isTrue);
      expect(resolved?.groupId, 'g1');
      expect(resolved?.channelType, GroupChannelType.memberChat);
    });

    test('ownerId fallback grants moderation when viewerRole is missing', () {
      const Group staleGroup = Group(
        groupId: 'g1',
        name: 'Trail Crew',
        description: 'Runs',
        category: 'running',
        privacy: GroupPrivacy.public,
        joinPolicy: GroupJoinPolicy.open,
        status: GroupStatus.active,
        memberCount: 2,
        capacity: 20,
        ownerId: 'owner-a',
        location: GroupLocation.empty,
        membershipStatus: GroupMembershipStatus.member,
        viewerRole: null,
      );

      expect(staleGroup.canModerateAs('owner-a'), isTrue);
    });

    test('normal member cannot moderate', () {
      const Group memberView = Group(
        groupId: 'g1',
        name: 'Trail Crew',
        description: 'Runs',
        category: 'running',
        privacy: GroupPrivacy.public,
        joinPolicy: GroupJoinPolicy.open,
        status: GroupStatus.active,
        memberCount: 2,
        capacity: 20,
        ownerId: 'owner-a',
        location: GroupLocation.empty,
        membershipStatus: GroupMembershipStatus.member,
        viewerRole: GroupMemberRole.member,
      );
      final SportsGroupChannelContext? resolved =
          SportsGroupChannelContextResolver.resolve(
            navigationContext: null,
            conversation: _sportsConversation(viewerUid: 'member-b'),
            group: memberView,
            channel: _channels.first,
            viewerUid: 'member-b',
          );

      expect(resolved?.canModerate, isFalse);
    });
  });
}
