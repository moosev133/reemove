import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/result/result.dart';
import '../data/repositories/firebase_group_notification_repository.dart';
import '../domain/entities/group_notification_preferences.dart';
import '../domain/repositories/group_notification_repository.dart';

final Provider<GroupNotificationRepository>
    groupNotificationRepositoryProvider = Provider((Ref ref) {
  return FirebaseGroupNotificationRepository(
    functions: ref.watch(firebaseFunctionsProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

final groupNotificationPreferencesProvider =
    FutureProvider.family<GroupNotificationPreferences, String>((
  Ref ref,
  String groupId,
) async {
  final FirebaseBootstrapReport report =
      ref.watch(firebaseBootstrapReportProvider);
  if (!report.isReady) {
    return const GroupNotificationPreferences();
  }

  final Result<GroupNotificationPreferences> result = await ref
      .read(groupNotificationRepositoryProvider)
      .getGroupNotificationPreferences(groupId: groupId);
  return _value(result);
});

final NotifierProvider<GroupNotificationActionController, AsyncValue<void>>
    groupNotificationActionControllerProvider =
    NotifierProvider<GroupNotificationActionController, AsyncValue<void>>(
      GroupNotificationActionController.new,
    );

class GroupNotificationActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue<void>.data(null);

  Future<bool> update({
    required String groupId,
    required GroupNotificationPreferences preferences,
  }) async {
    state = const AsyncValue<void>.loading();
    try {
      final Result<void> result = await ref
          .read(groupNotificationRepositoryProvider)
          .updateGroupNotificationPreferences(
            groupId: groupId,
            preferences: preferences,
          );
      _value(result);
      state = const AsyncValue<void>.data(null);
      return true;
    } catch (error) {
      state = AsyncValue<void>.error(error, StackTrace.current);
      return false;
    }
  }
}

T _value<T>(Result<T> result) => result.when<T>(
  success: (T value) => value,
  failure: (failure) => throw failure,
);


