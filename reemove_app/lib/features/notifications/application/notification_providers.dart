import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/result/result.dart';
import '../../messages/application/messaging_providers.dart';
import '../data/repositories/firebase_notification_repository.dart';
import '../domain/entities/app_notification.dart';
import '../domain/entities/notification_preferences.dart';
import '../domain/repositories/notification_repository.dart';

final Provider<NotificationRepository> notificationRepositoryProvider =
    Provider<NotificationRepository>((Ref ref) {
      return FirebaseNotificationRepository(
        firestore: ref.watch(firebaseFirestoreProvider),
        functions: ref.watch(firebaseFunctionsProvider),
        auth: ref.watch(firebaseAuthProvider),
      );
    });

final StreamProvider<List<AppNotification>> notificationsProvider =
    StreamProvider<List<AppNotification>>((Ref ref) async* {
      final FirebaseBootstrapReport report = ref.watch(
        firebaseBootstrapReportProvider,
      );
      if (!report.isReady) {
        yield const <AppNotification>[];
        return;
      }
      await for (final Result<List<AppNotification>> result
          in ref.watch(notificationRepositoryProvider).watchNotifications()) {
        yield _value(result);
      }
    });

final StreamProvider<int> notificationUnreadCountProvider = StreamProvider<int>(
  (Ref ref) async* {
    final FirebaseBootstrapReport report = ref.watch(
      firebaseBootstrapReportProvider,
    );
    if (!report.isReady) {
      yield 0;
      return;
    }
    await for (final Result<int> result
        in ref.watch(notificationRepositoryProvider).watchUnreadCount()) {
      yield _value(result);
    }
  },
);

final StreamProvider<UnifiedNotificationPreferences>
notificationPreferencesProvider =
    StreamProvider<UnifiedNotificationPreferences>((Ref ref) async* {
      final FirebaseBootstrapReport report = ref.watch(
        firebaseBootstrapReportProvider,
      );
      if (!report.isReady) {
        yield const UnifiedNotificationPreferences();
        return;
      }
      await for (final Result<UnifiedNotificationPreferences> result
          in ref.watch(notificationRepositoryProvider).watchPreferences()) {
        yield _value(result);
      }
    });

final StreamProvider<String> notificationOpenedRouteProvider =
    StreamProvider<String>((Ref ref) async* {
      final FirebaseBootstrapReport report = ref.watch(
        firebaseBootstrapReportProvider,
      );
      if (!report.isReady) {
        return;
      }
      final FirebaseMessaging messaging = ref.watch(firebaseMessagingProvider);
      final RemoteMessage? initial = await messaging.getInitialMessage();
      final String? initialRoute = notificationRoute(initial);
      if (initialRoute != null) {
        yield initialRoute;
      }
      await for (final RemoteMessage message
          in FirebaseMessaging.onMessageOpenedApp) {
        final String? route = notificationRoute(message);
        if (route != null) {
          yield route;
        }
      }
    });

final StreamProvider<RemoteMessage> foregroundNotificationProvider =
    StreamProvider<RemoteMessage>((Ref ref) {
      final FirebaseBootstrapReport report = ref.watch(
        firebaseBootstrapReportProvider,
      );
      if (!report.isReady) {
        return const Stream<RemoteMessage>.empty();
      }
      return FirebaseMessaging.onMessage;
    });

class NotificationHistoryState {
  const NotificationHistoryState({
    this.items = const <AppNotification>[],
    this.nextCursor,
    this.hasMore = true,
  });

  final List<AppNotification> items;
  final String? nextCursor;
  final bool hasMore;
}

final NotifierProvider<
  NotificationHistoryController,
  AsyncValue<NotificationHistoryState>
>
notificationHistoryProvider =
    NotifierProvider<
      NotificationHistoryController,
      AsyncValue<NotificationHistoryState>
    >(NotificationHistoryController.new);

class NotificationHistoryController
    extends Notifier<AsyncValue<NotificationHistoryState>> {
  @override
  AsyncValue<NotificationHistoryState> build() =>
      const AsyncValue<NotificationHistoryState>.data(
        NotificationHistoryState(),
      );

  Future<void> loadMore(List<AppNotification> latestItems) async {
    if (state.isLoading) {
      return;
    }
    final NotificationHistoryState current =
        state.value ?? const NotificationHistoryState();
    if (!current.hasMore ||
        (current.items.isEmpty && latestItems.length < 50)) {
      return;
    }
    final String? cursor =
        current.nextCursor ??
        (latestItems.isEmpty ? null : _cursor(latestItems.last));
    if (cursor == null) {
      return;
    }
    state = const AsyncValue<NotificationHistoryState>.loading();
    final Result<NotificationPage> result = await ref
        .read(notificationRepositoryProvider)
        .loadNotifications(cursor: cursor);
    state = result.when<AsyncValue<NotificationHistoryState>>(
      success: (NotificationPage page) {
        final Map<String, AppNotification> merged = <String, AppNotification>{
          for (final AppNotification item in current.items) item.id: item,
          for (final AppNotification item in page.items) item.id: item,
        };
        return AsyncValue<NotificationHistoryState>.data(
          NotificationHistoryState(
            items: merged.values.toList(growable: false),
            nextCursor: page.nextCursor,
            hasMore: page.nextCursor != null,
          ),
        );
      },
      failure: (Failure failure) =>
          AsyncValue<NotificationHistoryState>.data(current),
    );
  }

  void reset() {
    state = const AsyncValue<NotificationHistoryState>.data(
      NotificationHistoryState(),
    );
  }
}

final NotifierProvider<NotificationActionController, AsyncValue<void>>
notificationActionControllerProvider =
    NotifierProvider<NotificationActionController, AsyncValue<void>>(
      NotificationActionController.new,
    );

class NotificationActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue<void>.data(null);

  Future<bool> markRead(String notificationId) => _run(
    () => ref.read(notificationRepositoryProvider).markRead(notificationId),
  );

  Future<bool> markAllRead() =>
      _run(ref.read(notificationRepositoryProvider).markAllRead);

  Future<bool> delete(String notificationId) => _run(
    () => ref
        .read(notificationRepositoryProvider)
        .deleteNotification(notificationId),
  );

  Future<bool> clearRead() =>
      _run(ref.read(notificationRepositoryProvider).clearRead);

  Future<bool> updatePreferences(UnifiedNotificationPreferences preferences) =>
      _run(
        () => ref
            .read(notificationRepositoryProvider)
            .updatePreferences(preferences),
      );

  Future<bool> setMasterEnabled(
    UnifiedNotificationPreferences preferences,
  ) async {
    if (!preferences.masterEnabled) {
      return updatePreferences(preferences);
    }
    state = const AsyncValue<void>.loading();
    try {
      final NotificationSettings settings = await ref
          .read(firebaseMessagingProvider)
          .requestPermission(alert: true, badge: true, sound: true);
      final bool allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) {
        state = AsyncValue<void>.error(
          'Notifications are disabled in your device settings.',
          StackTrace.current,
        );
        return false;
      }
      final Result<void> result = await ref
          .read(notificationRepositoryProvider)
          .updatePreferences(preferences);
      final bool saved = result.when<bool>(
        success: (_) => true,
        failure: (Failure failure) {
          state = AsyncValue<void>.error(failure.message, StackTrace.current);
          return false;
        },
      );
      if (!saved) {
        return false;
      }
      ref.invalidate(messagingDeviceRegistrationProvider);
      await ref.read(messagingDeviceRegistrationProvider.future);
      state = const AsyncValue<void>.data(null);
      return true;
    } on Object catch (error, stackTrace) {
      state = AsyncValue<void>.error(error, stackTrace);
      return false;
    }
  }

  Future<bool> _run(Future<Result<void>> Function() action) async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await action();
    return result.when<bool>(
      success: (_) {
        state = const AsyncValue<void>.data(null);
        return true;
      },
      failure: (Failure failure) {
        state = AsyncValue<void>.error(failure.message, StackTrace.current);
        return false;
      },
    );
  }
}

String? notificationRoute(RemoteMessage? message) {
  if (message == null) {
    return null;
  }
  final Object? value = message.data['route'];
  if (value is! String) {
    return null;
  }
  final String route = value.trim();
  if (!route.startsWith('/') ||
      route.startsWith('//') ||
      route.contains(r'\') ||
      route.length > 500) {
    return null;
  }
  return route;
}

T _value<T>(Result<T> result) => result.when<T>(
  success: (T value) => value,
  failure: (Failure failure) => throw StateError(failure.message),
);

String _cursor(AppNotification value) =>
    '${value.latestAt.toUtc().microsecondsSinceEpoch}|${value.id}';
