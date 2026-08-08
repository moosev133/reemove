import '../../../../core/result/result.dart';
import '../entities/group_notification_preferences.dart';

abstract interface class GroupNotificationRepository {
  Future<Result<GroupNotificationPreferences>> getGroupNotificationPreferences({
    required String groupId,
  });

  Future<Result<void>> updateGroupNotificationPreferences({
    required String groupId,
    required GroupNotificationPreferences preferences,
  });
}


