import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/firebase/firebase_bootstrap.dart';
import 'package:reemove/core/providers/core_providers.dart';
import 'package:reemove/core/result/result.dart';
import 'package:reemove/features/authentication/application/authentication_providers.dart';
import 'package:reemove/features/authentication/domain/entities/auth_user.dart';
import 'package:reemove/features/feed/application/feed_providers.dart';
import 'package:reemove/features/groups/application/groups_providers.dart';
import 'package:reemove/features/groups/domain/entities/group.dart';
import 'package:reemove/features/groups/domain/entities/group_channel.dart';
import 'package:reemove/features/groups/domain/entities/group_enums.dart';
import 'package:reemove/features/groups/domain/entities/group_location.dart';
import 'package:reemove/features/groups/domain/entities/sports_group_channel_context.dart';
import 'package:reemove/features/groups/presentation/screens/group_channel_conversation_screen.dart';
import 'package:reemove/features/messages/application/messaging_providers.dart';
import 'package:reemove/features/messages/domain/entities/conversation.dart';
import 'package:reemove/features/messages/domain/entities/message.dart';
import 'package:reemove/features/messages/domain/entities/messaging_presence.dart';
import 'package:reemove/features/messages/domain/entities/messaging_user.dart';
import 'package:reemove/features/messages/domain/repositories/messaging_presence_repository.dart';

const AuthUser _owner = AuthUser(
  uid: 'owner-a',
  email: 'owner@test.com',
  emailVerified: true,
  isAnonymous: false,
  providers: <AuthProviderType>{AuthProviderType.password},
);

const AuthUser _member = AuthUser(
  uid: 'member-b',
  email: 'member@test.com',
  emailVerified: true,
  isAnonymous: false,
  providers: <AuthProviderType>{AuthProviderType.password},
);

Group _groupFor(AuthUser viewer) {
  final bool isOwner = viewer.uid == _owner.uid;
  return Group(
    groupId: 'g1',
    name: 'C2 Manual Test',
    description: 'Moderation actions',
    category: 'running',
    privacy: GroupPrivacy.hidden,
    joinPolicy: GroupJoinPolicy.inviteOnly,
    status: GroupStatus.active,
    memberCount: 2,
    capacity: 20,
    ownerId: _owner.uid,
    location: GroupLocation.empty,
    membershipStatus: isOwner
        ? GroupMembershipStatus.owner
        : GroupMembershipStatus.member,
    viewerRole: isOwner ? GroupMemberRole.owner : GroupMemberRole.member,
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

Conversation _conversationFor(AuthUser viewer) {
  return Conversation(
    id: 'c-member',
    type: ConversationType.group,
    title: 'C2 Manual Test',
    createdBy: _owner.uid,
    members: <ConversationMember>[
      ConversationMember(
        user: MessagingUser(
          id: viewer.uid,
          displayName: viewer.uid,
          username: viewer.uid,
          isVerified: false,
        ),
        role: viewer.uid == _owner.uid
            ? ConversationMemberRole.owner
            : ConversationMemberRole.member,
        joinedAt: DateTime.utc(2026, 1, 1),
        notificationsEnabled: true,
        unreadCount: 0,
      ),
      ConversationMember(
        user: MessagingUser(
          id: viewer.uid == _owner.uid ? _member.uid : _owner.uid,
          displayName: 'Peer',
          username: 'peer',
          isVerified: false,
        ),
        role: viewer.uid == _owner.uid
            ? ConversationMemberRole.member
            : ConversationMemberRole.owner,
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

ConversationMessage _peerMessage() {
  return ConversationMessage(
    id: 'm-peer',
    conversationId: 'c-member',
    sender: const MessagingUser(
      id: 'member-b',
      displayName: 'Member B',
      username: 'memberb',
      isVerified: false,
    ),
    kind: MessageKind.text,
    text: 'Hello from member B',
    attachments: const <MessageAttachment>[],
    reactionCounts: const <String, int>{},
    viewerReactions: const <String>{},
    sentAt: DateTime.utc(2026, 1, 1, 12),
    isDeleted: false,
  );
}

ConversationMessage _ownerMessage() {
  return ConversationMessage(
    id: 'm-owner',
    conversationId: 'c-member',
    sender: MessagingUser(
      id: _owner.uid,
      displayName: 'Owner A',
      username: 'ownera',
      isVerified: false,
    ),
    kind: MessageKind.text,
    text: 'Hello from owner A',
    attachments: const <MessageAttachment>[],
    reactionCounts: const <String, int>{},
    viewerReactions: const <String>{},
    sentAt: DateTime.utc(2026, 1, 1, 11),
    isDeleted: false,
  );
}

ConversationMessage _deletedPeerMessage() {
  return ConversationMessage(
    id: 'm-peer',
    conversationId: 'c-member',
    sender: const MessagingUser(
      id: 'member-b',
      displayName: 'Member B',
      username: 'memberb',
      isVerified: false,
    ),
    kind: MessageKind.deleted,
    text: '',
    attachments: const <MessageAttachment>[],
    reactionCounts: const <String, int>{},
    viewerReactions: const <String>{},
    sentAt: DateTime.utc(2026, 1, 1, 12),
    isDeleted: true,
  );
}

List<Override> _baseOverrides({
  required AuthUser viewer,
  required List<ConversationMessage> messages,
  Stream<List<ConversationMessage>>? messageStream,
}) {
  return <Override>[
    firebaseBootstrapReportProvider.overrideWithValue(
      const FirebaseBootstrapReport(
        status: FirebaseBootstrapStatus.ready,
        appCheckEnabled: false,
        emulatorsEnabled: false,
      ),
    ),
    messagingPresenceRepositoryProvider.overrideWithValue(
      _FakeMessagingPresenceRepository(),
    ),
    currentAuthUserProvider.overrideWith(
      (Ref ref) => Stream<AuthUser?>.value(viewer),
    ),
    groupProvider('g1').overrideWith((Ref ref) async => _groupFor(viewer)),
    groupChannelsProvider('g1').overrideWith((Ref ref) async => _channels),
    conversationProvider('c-member').overrideWith(
      (Ref ref) => Stream<Conversation?>.value(_conversationFor(viewer)),
    ),
    recentMessagesProvider('c-member').overrideWith(
      (Ref ref) =>
          messageStream ?? Stream<List<ConversationMessage>>.value(messages),
    ),
    connectivityResultsProvider.overrideWith(
      (Ref ref) => Stream<List<ConnectivityResult>>.value(
        const <ConnectivityResult>[ConnectivityResult.wifi],
      ),
    ),
  ];
}

Future<void> _pumpChannelScreen(
  WidgetTester tester, {
  required AuthUser viewer,
  required List<ConversationMessage> messages,
  Stream<List<ConversationMessage>>? messageStream,
  List<Override> extraOverrides = const <Override>[],
  MessagingActionController Function()? actionController,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ..._baseOverrides(
          viewer: viewer,
          messages: messages,
          messageStream: messageStream,
        ),
        messagingActionControllerProvider.overrideWith(
          actionController ?? MessagingActionController.new,
        ),
        ...extraOverrides,
      ],
      child: const MaterialApp(
        home: GroupChannelConversationScreen(
          groupId: 'g1',
          channelType: 'member_chat',
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets(
    'owner opening group channel sees manager delete on peer message',
    (WidgetTester tester) async {
      await _pumpChannelScreen(
        tester,
        viewer: _owner,
        messages: <ConversationMessage>[_peerMessage()],
      );

      expect(find.textContaining('C2 Manual Test · Member chat'), findsOneWidget);
      await tester.longPress(find.text('Hello from member B'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('message-action-delete-moderator')), findsOneWidget);
      expect(find.text('Remove for everyone (manager)'), findsOneWidget);
      expect(find.text('Report message'), findsNothing);
    },
  );

  testWidgets(
    'member sees Reply and Report only on another user message',
    (WidgetTester tester) async {
      await _pumpChannelScreen(
        tester,
        viewer: _member,
        messages: <ConversationMessage>[_ownerMessage()],
      );

      await tester.longPress(find.text('Hello from owner A'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('message-action-delete-moderator')), findsNothing);
      expect(find.byKey(const Key('message-action-delete-own')), findsNothing);
      expect(find.text('Report message'), findsOneWidget);
    },
  );

  testWidgets(
    'owner moderation delete confirms and shows success feedback',
    (WidgetTester tester) async {
      await _pumpChannelScreen(
        tester,
        viewer: _owner,
        messages: <ConversationMessage>[_peerMessage()],
        actionController: _SuccessfulDeleteController.new,
      );

      await tester.longPress(find.text('Hello from member B'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('message-action-delete-moderator')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Message removed.'), findsOneWidget);
    },
  );
}

class _SuccessfulDeleteController extends MessagingActionController {
  @override
  Future<bool> delete({
    required String conversationId,
    required String messageId,
  }) async {
    state = const AsyncData<void>(null);
    return true;
  }
}

class _FakeMessagingPresenceRepository implements MessagingPresenceRepository {
  @override
  Future<Result<void>> joinConversation({
    required String conversationId,
    required String userId,
  }) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> leaveConversation({
    required String conversationId,
    required String userId,
  }) async =>
      const Success<void>(null);

  @override
  Stream<Result<Map<String, MessagingPresence>>> watchPresence(
    String conversationId,
  ) =>
      Stream<Result<Map<String, MessagingPresence>>>.value(
        const Success<Map<String, MessagingPresence>>(<String, MessagingPresence>{}),
      );

  @override
  Stream<Result<List<TypingParticipant>>> watchTyping(String conversationId) =>
      Stream<Result<List<TypingParticipant>>>.value(
        const Success<List<TypingParticipant>>(<TypingParticipant>[]),
      );

  @override
  Future<Result<void>> setTyping({
    required String conversationId,
    required String userId,
    required bool isTyping,
  }) async =>
      const Success<void>(null);
}

