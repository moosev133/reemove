import '../../../../core/result/result.dart';
import '../entities/app_notification.dart';
import '../entities/notification_preferences.dart';

abstract interface class NotificationRepository {
  Stream<Result<List<AppNotification>>> watchNotifications({int limit = 100});

  Future<Result<NotificationPage>> loadNotifications({
    int limit = 50,
    String? cursor,
  });

  Stream<Result<int>> watchUnreadCount();

  Stream<Result<UnifiedNotificationPreferences>> watchPreferences();

  Future<Result<void>> markRead(String notificationId);

  Future<Result<void>> markAllRead();

  Future<Result<void>> deleteNotification(String notificationId);

  Future<Result<void>> clearRead();

  Future<Result<void>> updatePreferences(
    UnifiedNotificationPreferences preferences,
  );
}
