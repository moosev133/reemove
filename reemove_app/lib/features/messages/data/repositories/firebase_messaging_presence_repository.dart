import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/messaging_presence.dart';
import '../../domain/repositories/messaging_presence_repository.dart';
import '../services/messaging_failure_mapper.dart';

class FirebaseMessagingPresenceRepository
    implements MessagingPresenceRepository {
  const FirebaseMessagingPresenceRepository(this._database);

  final FirebaseDatabase _database;

  @override
  Future<Result<void>> joinConversation({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final DatabaseReference presence = _database.ref(
        'presence/$conversationId/$userId',
      );
      final DatabaseReference typing = _database.ref(
        'typing/$conversationId/$userId',
      );
      await presence.onDisconnect().remove();
      await typing.onDisconnect().remove();
      await presence.set(<String, Object>{
        'state': 'online',
        'lastChanged': ServerValue.timestamp,
      });
      return const Success<void>(null);
    } on FirebaseException catch (error) {
      return FailureResult<void>(MessagingFailureMapper.fromDatabase(error));
    } on Object catch (error) {
      return FailureResult<void>(MessagingFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> leaveConversation({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _database.ref().update(<String, Object?>{
        'presence/$conversationId/$userId': null,
        'typing/$conversationId/$userId': null,
      });
      return const Success<void>(null);
    } on FirebaseException catch (error) {
      return FailureResult<void>(MessagingFailureMapper.fromDatabase(error));
    } on Object catch (error) {
      return FailureResult<void>(MessagingFailureMapper.unexpected(error));
    }
  }

  @override
  Stream<Result<Map<String, MessagingPresence>>> watchPresence(
    String conversationId,
  ) async* {
    try {
      await for (final DatabaseEvent event
          in _database.ref('presence/$conversationId').onValue) {
        final Map<Object?, Object?> raw = event.snapshot.value is Map
            ? (event.snapshot.value as Map).cast<Object?, Object?>()
            : const <Object?, Object?>{};
        final Map<String, MessagingPresence> values =
            <String, MessagingPresence>{};
        for (final MapEntry<Object?, Object?> entry in raw.entries) {
          if (entry.key is! String || entry.value is! Map) {
            continue;
          }
          final Map<Object?, Object?> data = (entry.value as Map)
              .cast<Object?, Object?>();
          final String state = data['state'] as String? ?? 'offline';
          final num lastChanged = data['lastChanged'] as num? ?? 0;
          values[entry.key as String] = MessagingPresence(
            userId: entry.key as String,
            state: switch (state) {
              'online' => MessagingPresenceState.online,
              'away' => MessagingPresenceState.away,
              _ => MessagingPresenceState.offline,
            },
            lastChanged: DateTime.fromMillisecondsSinceEpoch(
              lastChanged.toInt(),
            ),
          );
        }
        yield Success<Map<String, MessagingPresence>>(values);
      }
    } on FirebaseException catch (error) {
      yield FailureResult<Map<String, MessagingPresence>>(
        MessagingFailureMapper.fromDatabase(error),
      );
    } on Object catch (error) {
      yield FailureResult<Map<String, MessagingPresence>>(
        MessagingFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<List<TypingParticipant>>> watchTyping(
    String conversationId,
  ) async* {
    try {
      await for (final DatabaseEvent event
          in _database.ref('typing/$conversationId').onValue) {
        final Map<Object?, Object?> raw = event.snapshot.value is Map
            ? (event.snapshot.value as Map).cast<Object?, Object?>()
            : const <Object?, Object?>{};
        final DateTime cutoff = DateTime.now().subtract(
          const Duration(seconds: 8),
        );
        final List<TypingParticipant> values = <TypingParticipant>[];
        for (final MapEntry<Object?, Object?> entry in raw.entries) {
          if (entry.key is! String || entry.value is! Map) {
            continue;
          }
          final Map<Object?, Object?> data = (entry.value as Map)
              .cast<Object?, Object?>();
          final bool isTyping = data['isTyping'] as bool? ?? false;
          final num updatedAt = data['updatedAt'] as num? ?? 0;
          final DateTime updated = DateTime.fromMillisecondsSinceEpoch(
            updatedAt.toInt(),
          );
          if (isTyping && updated.isAfter(cutoff)) {
            values.add(
              TypingParticipant(
                userId: entry.key as String,
                isTyping: true,
                updatedAt: updated,
              ),
            );
          }
        }
        yield Success<List<TypingParticipant>>(
          List<TypingParticipant>.unmodifiable(values),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<List<TypingParticipant>>(
        MessagingFailureMapper.fromDatabase(error),
      );
    } on Object catch (error) {
      yield FailureResult<List<TypingParticipant>>(
        MessagingFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<void>> setTyping({
    required String conversationId,
    required String userId,
    required bool isTyping,
  }) async {
    try {
      final DatabaseReference reference = _database.ref(
        'typing/$conversationId/$userId',
      );
      if (!isTyping) {
        await reference.remove();
      } else {
        await reference.set(<String, Object>{
          'isTyping': true,
          'updatedAt': ServerValue.timestamp,
        });
      }
      return const Success<void>(null);
    } on FirebaseException catch (error) {
      return FailureResult<void>(MessagingFailureMapper.fromDatabase(error));
    } on Object catch (error) {
      return FailureResult<void>(MessagingFailureMapper.unexpected(error));
    }
  }
}
