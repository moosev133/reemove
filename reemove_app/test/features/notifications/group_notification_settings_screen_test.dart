import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/groups/domain/entities/group.dart';
import 'package:reemove/features/groups/domain/entities/group_enums.dart';
import 'package:reemove/features/groups/domain/entities/group_location.dart';
import 'package:reemove/features/groups/application/groups_providers.dart';
import 'package:reemove/features/notifications/application/group_notification_providers.dart';
import 'package:reemove/features/notifications/domain/entities/group_notification_preferences.dart';
import 'package:reemove/features/notifications/domain/repositories/group_notification_repository.dart';
import 'package:reemove/features/notifications/presentation/screens/group_notification_settings_screen.dart';
import 'package:reemove/core/providers/core_providers.dart';
import 'package:reemove/core/firebase/firebase_bootstrap.dart';
import 'package:reemove/core/result/result.dart';

class _FakeGroupNotificationRepository implements GroupNotificationRepository {
  _FakeGroupNotificationRepository(this._prefs);

  GroupNotificationPreferences _prefs;
  GroupNotificationPreferences get prefs => _prefs;

  @override
  Future<Result<GroupNotificationPreferences>> getGroupNotificationPreferences({
    required String groupId,
  }) async {
    return Success<GroupNotificationPreferences>(_prefs);
  }

  @override
  Future<Result<void>> updateGroupNotificationPreferences({
    required String groupId,
    required GroupNotificationPreferences preferences,
  }) async {
    _prefs = preferences;
    return const Success<void>(null);
  }
}

void main() {
  testWidgets('group notification settings toggles persist via repository', (
    WidgetTester tester,
  ) async {
    const String groupId = 'g1';

    final Group group = Group(
      groupId: groupId,
      name: 'Test Group',
      description: 'desc',
      category: 'running',
      privacy: GroupPrivacy.private,
      joinPolicy: GroupJoinPolicy.open,
      status: GroupStatus.active,
      memberCount: 1,
      capacity: 20,
      ownerId: 'owner',
      location: GroupLocation.empty,
      membershipStatus: GroupMembershipStatus.member,
      viewerRole: GroupMemberRole.member,
      memberChatConversationId: 'c1',
      announcementsConversationId: 'c2',
    );

    final _FakeGroupNotificationRepository fakeRepo = _FakeGroupNotificationRepository(
      const GroupNotificationPreferences(
        muted: false,
        memberChatEnabled: true,
        announcementsEnabled: true,
        sessionsEnabled: true,
        invitationsEnabled: true,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseBootstrapReportProvider.overrideWithValue(
            const FirebaseBootstrapReport(
              status: FirebaseBootstrapStatus.ready,
              appCheckEnabled: false,
              emulatorsEnabled: true,
            ),
          ),
          groupProvider(groupId).overrideWith((Ref ref) async => group),
          groupNotificationRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: GroupNotificationSettingsScreen(groupId: groupId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Member chat starts enabled.
    SwitchListTile memberChatTile =
        tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Member chat'),
        );
    expect(memberChatTile.value, isTrue);

    // Disable member chat notifications for this group.
    await tester.tap(find.widgetWithText(SwitchListTile, 'Member chat'));
    await tester.pumpAndSettle();

    memberChatTile =
        tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Member chat'),
        );
    expect(memberChatTile.value, isFalse);
    expect(fakeRepo.prefs.memberChatEnabled, isFalse);
  });
}


