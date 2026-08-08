import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reemove/app/router/app_routes.dart';
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
import 'package:reemove/features/messages/application/messaging_providers.dart';
import 'package:reemove/features/messages/domain/entities/conversation.dart';
import 'package:reemove/features/messages/domain/entities/message.dart';
import 'package:reemove/features/messages/domain/entities/messaging_presence.dart';
import 'package:reemove/features/messages/domain/entities/messaging_user.dart';
import 'package:reemove/features/messages/domain/repositories/messaging_presence_repository.dart';
import 'package:reemove/features/messages/presentation/screens/conversation_screen.dart';
import 'package:reemove/features/groups/presentation/screens/group_channel_conversation_screen.dart';

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

Group _groupOwner() {
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
    membershipStatus: GroupMembershipStatus.owner,
    viewerRole: GroupMemberRole.owner,
  );
}

Conversation _conversationWithViewerRole(ConversationMemberRole viewerRole) {
  return Conversation(
    id: 'c-member',
    type: ConversationType.group,
    title: 'C2 Manual Test',
    createdBy: _owner.uid,
    members: <ConversationMember>[
      ConversationMember(
        user: MessagingUser(
          id: _owner.uid,
          displayName: 'Owner',
          username: 'owner',
          isVerified: false,
        ),
        role: viewerRole,
        joinedAt: DateTime.utc(2026, 1, 1),
        notificationsEnabled: true,
        unreadCount: 0,
      ),
      ConversationMember(
        user: const MessagingUser(
          id: 'member-b',
          displayName: 'Member B',
          username: 'memberb',
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
    source: 'sports_group',
    sportsGroupId: 'g1',
    sportsChannelType: 'member_chat',
  );
}

Conversation _conversationWithMemberViewerRole(
  ConversationMemberRole viewerRole,
) {
  return Conversation(
    id: 'c-member',
    type: ConversationType.group,
    title: 'C2 Manual Test',
    createdBy: _owner.uid,
    members: <ConversationMember>[
      ConversationMember(
        user: MessagingUser(
          id: _owner.uid,
          displayName: 'Owner',
          username: 'owner',
          isVerified: false,
        ),
        role: ConversationMemberRole.member,
        joinedAt: DateTime.utc(2026, 1, 1),
        notificationsEnabled: true,
        unreadCount: 0,
      ),
      ConversationMember(
        user: const MessagingUser(
          id: 'member-b',
          displayName: 'Member B',
          username: 'memberb',
          isVerified: false,
        ),
        role: viewerRole,
        joinedAt: DateTime.utc(2026, 1, 1),
        notificationsEnabled: true,
        unreadCount: 0,
      ),
    ],
    memberCount: 2,
    moderationState: 'active',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    source: 'sports_group',
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
      username: 'owner',
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

Group _groupMember() {
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
    membershipStatus: GroupMembershipStatus.member,
    viewerRole: GroupMemberRole.member,
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
    viewOnceSupported: false,
  ),
];

class _FakeMessagingPresenceRepository implements MessagingPresenceRepository {
  @override
  Future<Result<void>> joinConversation({
    required String conversationId,
    required String userId,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> leaveConversation({
    required String conversationId,
    required String userId,
  }) async => const Success<void>(null);

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

GoRouter _messagesRouter() {
  return GoRouter(
    initialLocation: AppRoutes.conversation('c-member'),
    routes: <RouteBase>[
      GoRoute(
        path: '/messages/:conversationId',
        builder: (BuildContext context, GoRouterState state) {
          return ConversationScreen(
            conversationId: state.pathParameters['conversationId'] ?? '',
          );
        },
      ),
    ],
  );
}

GoRouter _groupChannelRouter() {
  return GoRouter(
    initialLocation: AppRoutes.groupChannel('g1', 'member_chat'),
    routes: <RouteBase>[
      GoRoute(
        path: '/discover/groups/:groupId/channels/:channelType',
        builder: (BuildContext context, GoRouterState state) {
          return GroupChannelConversationScreen(
            groupId: state.pathParameters['groupId'] ?? '',
            channelType: state.pathParameters['channelType'] ?? 'member_chat',
          );
        },
      ),
    ],
  );
}

void main() {
  testWidgets(
    'Group channel route: owner sees manager delete (staging-shaped conversation)',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
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
              (Ref ref) => Stream<AuthUser?>.value(_owner),
            ),
            groupProvider('g1').overrideWith((Ref ref) async => _groupOwner()),
            groupChannelsProvider('g1').overrideWith(
              (Ref ref) async => _channels,
            ),
            conversationProvider('c-member').overrideWith(
              (Ref ref) => Stream<Conversation?>.value(
                _conversationWithViewerRole(ConversationMemberRole.owner),
              ),
            ),
            recentMessagesProvider('c-member').overrideWith(
              (Ref ref) => Stream<List<ConversationMessage>>.value(
                <ConversationMessage>[
                  _peerMessage(),
                ],
              ),
            ),
            connectivityResultsProvider.overrideWith(
              (Ref ref) => Stream<List<ConnectivityResult>>.value(
                const <ConnectivityResult>[ConnectivityResult.wifi],
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: _groupChannelRouter(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.longPress(find.text('Hello from member B'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('message-action-delete-moderator')),
        findsOneWidget,
      );
      expect(find.text('Remove for everyone (manager)'), findsOneWidget);
    },
  );

  testWidgets(
    'Group channel route: member sees Reply/Report only on owner message',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
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
              (Ref ref) => Stream<AuthUser?>.value(_member),
            ),
            groupProvider('g1').overrideWith((Ref ref) async => _groupMember()),
            groupChannelsProvider('g1').overrideWith(
              (Ref ref) async => _channels,
            ),
            conversationProvider('c-member').overrideWith(
              (Ref ref) => Stream<Conversation?>.value(
                _conversationWithMemberViewerRole(
                  ConversationMemberRole.member,
                ),
              ),
            ),
            recentMessagesProvider('c-member').overrideWith(
              (Ref ref) => Stream<List<ConversationMessage>>.value(
                <ConversationMessage>[
                  _ownerMessage(),
                ],
              ),
            ),
            connectivityResultsProvider.overrideWith(
              (Ref ref) => Stream<List<ConnectivityResult>>.value(
                const <ConnectivityResult>[ConnectivityResult.wifi],
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: _groupChannelRouter(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.longPress(find.text('Hello from owner A'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('message-action-delete-moderator')),
        findsNothing,
      );
      expect(find.byKey(const Key('message-action-delete-own')), findsNothing);
      expect(find.text('Report message'), findsOneWidget);
    },
  );

  testWidgets(
    'Messages tab route: owner sees manager delete without sports navigation context',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
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
              (Ref ref) => Stream<AuthUser?>.value(_owner),
            ),
            groupProvider('g1').overrideWith((Ref ref) async => _groupOwner()),
            groupChannelsProvider('g1').overrideWith(
              (Ref ref) async => _channels,
            ),
            conversationProvider('c-member').overrideWith(
              (Ref ref) => Stream<Conversation?>.value(
                _conversationWithViewerRole(ConversationMemberRole.owner),
              ),
            ),
            recentMessagesProvider('c-member').overrideWith(
              (Ref ref) => Stream<List<ConversationMessage>>.value(
                <ConversationMessage>[
                  _peerMessage(),
                ],
              ),
            ),
            connectivityResultsProvider.overrideWith(
              (Ref ref) => Stream<List<ConnectivityResult>>.value(
                const <ConnectivityResult>[ConnectivityResult.wifi],
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: _messagesRouter(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.longPress(find.text('Hello from member B'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('message-action-delete-moderator')),
        findsOneWidget,
      );
    },
  );
}

