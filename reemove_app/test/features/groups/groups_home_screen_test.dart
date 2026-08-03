import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/groups/application/groups_providers.dart';
import 'package:reemove/features/groups/domain/entities/group.dart';
import 'package:reemove/features/groups/domain/entities/group_membership.dart';
import 'package:reemove/features/groups/presentation/screens/groups_home_screen.dart';

void main() {
  testWidgets('GroupsHomeScreen shows empty states when lists are empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myGroupsProvider.overrideWith(
            (Ref ref) async => const <MyGroupMembership>[],
          ),
          discoverableGroupsProvider(null).overrideWith(
            (Ref ref) async => const <Group>[],
          ),
        ],
        child: const MaterialApp(home: GroupsHomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('No groups yet'), findsOneWidget);
    expect(find.text('Nothing to discover'), findsOneWidget);
    expect(find.text('Groups'), findsWidgets);
  });
}
