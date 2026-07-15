import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/database/firestore_parser.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notification_repository.dart';
import '../dto/app_notification_dto.dart';
import '../mappers/notification_mapper.dart';
import '../services/notification_failure_mapper.dart';

class FirebaseNotificationRepository implements NotificationRepository {
  const FirebaseNotificationRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _functions = functions,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  String get _uid {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in to access notifications.');
    }
    return uid;
  }

  CollectionReference<AppNotificationDto> get _notifications => _firestore
      .collection('users/$_uid/notifications')
      .withConverter<AppNotificationDto>(
        fromFirestore: AppNotificationDto.fromFirestore,
        toFirestore: (snapshot, _) => throw UnsupportedError('Server managed.'),
      );

  @override
  Stream<Result<List<AppNotification>>> watchNotifications({
    int limit = 50,
  }) async* {
    try {
      final Query<AppNotificationDto> query = _notifications
          .where('deletedAt', isNull: true)
          .orderBy('latestAt', descending: true)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(limit.clamp(1, 100).toInt());
      await for (final QuerySnapshot<AppNotificationDto> snapshot
          in query.snapshots()) {
        yield Success<List<AppNotification>>(
          snapshot.docs
              .map(
                (QueryDocumentSnapshot<AppNotificationDto> item) =>
                    item.data().toDomain(),
              )
              .toList(growable: false),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<List<AppNotification>>(
        NotificationFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<List<AppNotification>>(
        NotificationFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<NotificationPage>> loadNotifications({
    int limit = 50,
    String? cursor,
  }) async {
    try {
      final int boundedLimit = limit.clamp(1, 100).toInt();
      Query<AppNotificationDto> query = _notifications
          .where('deletedAt', isNull: true)
          .orderBy('latestAt', descending: true)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(boundedLimit);
      final _NotificationCursor? parsed = _NotificationCursor.tryParse(cursor);
      if (parsed != null) {
        query = query.startAfter(<Object>[
          Timestamp(
            parsed.microseconds ~/ Duration.microsecondsPerSecond,
            (parsed.microseconds % Duration.microsecondsPerSecond) * 1000,
          ),
          parsed.id,
        ]);
      }
      final QuerySnapshot<AppNotificationDto> snapshot = await query.get();
      final List<AppNotification> items = snapshot.docs
          .map(
            (QueryDocumentSnapshot<AppNotificationDto> item) =>
                item.data().toDomain(),
          )
          .toList(growable: false);
      return Success<NotificationPage>(
        NotificationPage(
          items: items,
          nextCursor: items.length < boundedLimit
              ? null
              : _NotificationCursor.fromNotification(items.last).encode(),
        ),
      );
    } on FirebaseException catch (error) {
      return FailureResult<NotificationPage>(
        NotificationFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      return FailureResult<NotificationPage>(
        NotificationFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<int>> watchUnreadCount() async* {
    try {
      final DocumentReference<FirestoreMap> reference = _firestore.doc(
        'users/$_uid/private/notification_summary',
      );
      await for (final DocumentSnapshot<FirestoreMap> snapshot
          in reference.snapshots()) {
        final FirestoreMap data = snapshot.data() ?? <String, dynamic>{};
        yield Success<int>(
          FirestoreParser.integer(
            data,
            'unreadCount',
            fallback: 0,
          ).clamp(0, 999).toInt(),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<int>(NotificationFailureMapper.fromFirestore(error));
    } on Object catch (error) {
      yield FailureResult<int>(NotificationFailureMapper.unexpected(error));
    }
  }

  @override
  Stream<Result<UnifiedNotificationPreferences>> watchPreferences() async* {
    try {
      final DocumentReference<FirestoreMap> reference = _firestore.doc(
        'users/$_uid/private/preferences',
      );
      await for (final DocumentSnapshot<FirestoreMap> snapshot
          in reference.snapshots()) {
        final FirestoreMap root = snapshot.data() ?? <String, dynamic>{};
        final FirestoreMap data = FirestoreParser.map(root, 'notifications');
        final bool activity = FirestoreParser.boolean(
          data,
          'activity',
          fallback: true,
        );
        final FirestoreMap quiet = FirestoreParser.map(data, 'quietHours');
        yield Success<UnifiedNotificationPreferences>(
          UnifiedNotificationPreferences(
            masterEnabled: FirestoreParser.boolean(
              data,
              'masterEnabled',
              fallback: false,
            ),
            showPreviews: FirestoreParser.boolean(
              data,
              'showPreviews',
              fallback: true,
            ),
            activity: activity,
            messages: FirestoreParser.boolean(data, 'messages', fallback: true),
            events: FirestoreParser.boolean(data, 'events', fallback: true),
            challenges: FirestoreParser.boolean(
              data,
              'challenges',
              fallback: true,
            ),
            marketplace: FirestoreParser.boolean(
              data,
              'marketplace',
              fallback: activity,
            ),
            system: FirestoreParser.boolean(data, 'system', fallback: true),
            productUpdates: FirestoreParser.boolean(
              data,
              'productUpdates',
              fallback: false,
            ),
            quietHours: NotificationQuietHours(
              enabled: FirestoreParser.boolean(
                quiet,
                'enabled',
                fallback: false,
              ),
              startMinutes: FirestoreParser.integer(
                quiet,
                'startMinutes',
                fallback: 22 * 60,
              ),
              endMinutes: FirestoreParser.integer(
                quiet,
                'endMinutes',
                fallback: 7 * 60,
              ),
              utcOffsetMinutes: FirestoreParser.integer(
                quiet,
                'utcOffsetMinutes',
                fallback: DateTime.now().timeZoneOffset.inMinutes,
              ),
            ),
          ),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<UnifiedNotificationPreferences>(
        NotificationFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<UnifiedNotificationPreferences>(
        NotificationFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<void>> markRead(String notificationId) => _call(
    'markNotificationRead',
    <String, Object?>{'notificationId': notificationId},
  );

  @override
  Future<Result<void>> markAllRead() =>
      _call('markAllNotificationsRead', const <String, Object?>{});

  @override
  Future<Result<void>> deleteNotification(String notificationId) => _call(
    'deleteNotification',
    <String, Object?>{'notificationId': notificationId},
  );

  @override
  Future<Result<void>> clearRead() =>
      _call('clearReadNotifications', const <String, Object?>{});

  @override
  Future<Result<void>> updatePreferences(
    UnifiedNotificationPreferences preferences,
  ) => _call('updateNotificationPreferences', <String, Object?>{
    'preferences': preferences.toCallableJson(),
  });

  Future<Result<void>> _call(String name, Map<String, Object?> data) async {
    try {
      await _functions.httpsCallable(name).call<Map<String, dynamic>>(data);
      return const Success<void>(null);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<void>(
        NotificationFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<void>(NotificationFailureMapper.unexpected(error));
    }
  }
}

class _NotificationCursor {
  const _NotificationCursor(this.microseconds, this.id);

  factory _NotificationCursor.fromNotification(AppNotification value) =>
      _NotificationCursor(
        value.latestAt.toUtc().microsecondsSinceEpoch,
        value.id,
      );

  final int microseconds;
  final String id;

  String encode() => '$microseconds|$id';

  static _NotificationCursor? tryParse(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final int separator = value.indexOf('|');
    if (separator <= 0 || separator == value.length - 1) {
      return null;
    }
    final int? micros = int.tryParse(value.substring(0, separator));
    final String id = value.substring(separator + 1);
    if (micros == null || id.isEmpty) {
      return null;
    }
    return _NotificationCursor(micros, id);
  }
}
