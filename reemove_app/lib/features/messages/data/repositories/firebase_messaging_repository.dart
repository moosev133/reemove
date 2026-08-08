import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/database/firestore_parser.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../groups/domain/entities/group_enums.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/messaging_action.dart';
import '../../domain/repositories/messaging_repository.dart';
import '../dto/conversation_dto.dart';
import '../dto/message_dto.dart';
import '../mappers/messaging_mapper.dart';
import '../services/messaging_failure_mapper.dart';

class FirebaseMessagingRepository implements MessagingRepository {
  const FirebaseMessagingRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _functions = functions,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  @override
  Stream<Result<List<ConversationSummary>>> watchInbox({
    required String userId,
    bool archived = false,
    int limit = 50,
  }) async* {
    try {
      final Query<ConversationSummaryDto> query = _inbox(userId)
          .where('isArchived', isEqualTo: archived)
          .orderBy('updatedAt', descending: true)
          .limit(limit.clamp(1, 100).toInt());
      await for (final QuerySnapshot<ConversationSummaryDto> snapshot
          in query.snapshots()) {
        yield Success<List<ConversationSummary>>(
          snapshot.docs
              .map(
                (QueryDocumentSnapshot<ConversationSummaryDto> item) =>
                    item.data().toDomain(),
              )
              .toList(growable: false),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<List<ConversationSummary>>(
        MessagingFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<List<ConversationSummary>>(
        MessagingFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<int>> watchUnreadCount(String userId) async* {
    try {
      final Query<ConversationSummaryDto> query = _inbox(userId)
          .where('isArchived', isEqualTo: false)
          .where('unreadCount', isGreaterThan: 0)
          .limit(100);
      await for (final QuerySnapshot<ConversationSummaryDto> snapshot
          in query.snapshots()) {
        final int total = snapshot.docs.fold<int>(
          0,
          (int sum, QueryDocumentSnapshot<ConversationSummaryDto> item) =>
              sum + item.data().unreadCount,
        );
        yield Success<int>(total.clamp(0, 999));
      }
    } on FirebaseException catch (error) {
      yield FailureResult<int>(MessagingFailureMapper.fromFirestore(error));
    } on Object catch (error) {
      yield FailureResult<int>(MessagingFailureMapper.unexpected(error));
    }
  }

  @override
  Stream<Result<Conversation?>> watchConversation({
    required String conversationId,
    required String viewerId,
  }) {
    final StreamController<Result<Conversation?>> controller =
        StreamController<Result<Conversation?>>();
    ConversationDto? conversation;
    List<ConversationMemberDto>? members;

    void publish() {
      if (conversation == null) {
        controller.add(const Success<Conversation?>(null));
        return;
      }
      if (members == null) {
        return;
      }
      controller.add(
        Success<Conversation?>(conversationToDomain(conversation!, members!)),
      );
    }

    final StreamSubscription<DocumentSnapshot<ConversationDto>>
    conversationSub = _conversations
        .doc(conversationId)
        .snapshots()
        .listen(
          (DocumentSnapshot<ConversationDto> snapshot) {
            conversation = snapshot.data();
            publish();
          },
          onError: (Object error, StackTrace stackTrace) {
            controller.add(FailureResult<Conversation?>(_failure(error)));
          },
        );
    final StreamSubscription<QuerySnapshot<ConversationMemberDto>> memberSub =
        _members(conversationId)
            .orderBy('joinedAt')
            .limit(100)
            .snapshots()
            .listen(
              (QuerySnapshot<ConversationMemberDto> snapshot) {
                members = snapshot.docs
                    .map(
                      (QueryDocumentSnapshot<ConversationMemberDto> item) =>
                          item.data(),
                    )
                    .toList(growable: false);
                publish();
              },
              onError: (Object error, StackTrace stackTrace) {
                controller.add(FailureResult<Conversation?>(_failure(error)));
              },
            );

    controller.onCancel = () async {
      await conversationSub.cancel();
      await memberSub.cancel();
      if (!controller.isClosed) {
        await controller.close();
      }
    };
    return controller.stream;
  }

  @override
  Stream<Result<List<ConversationMessage>>> watchRecentMessages({
    required String conversationId,
    required String viewerId,
    int limit = 40,
  }) async* {
    try {
      final Query<MessageDto> query = _messages(conversationId)
          .orderBy('sentAt', descending: true)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(limit.clamp(1, 100).toInt());
      await for (final QuerySnapshot<MessageDto> snapshot
          in query.snapshots()) {
        final Map<String, Set<String>> reactions = await _viewerReactions(
          viewerId,
          conversationId,
          snapshot.docs.map(
            (QueryDocumentSnapshot<MessageDto> item) => item.id,
          ),
        );
        final Map<String, Set<String>> viewOnceClaims =
            await _viewerViewOnceClaims(
              viewerId,
              conversationId,
              snapshot.docs.map(
                (QueryDocumentSnapshot<MessageDto> item) => item.data(),
              ),
            );
        final List<ConversationMessage> messages =
            snapshot.docs
                .map(
                  (QueryDocumentSnapshot<MessageDto> item) =>
                      item.data().toDomain(
                        viewerReactions: reactions[item.id] ?? const <String>{},
                        consumedViewOnceAttachmentIds:
                            viewOnceClaims[item.id] ?? const <String>{},
                      ),
                )
                .toList(growable: true)
              ..sort(
                (ConversationMessage first, ConversationMessage second) =>
                    first.sentAt.compareTo(second.sentAt),
              );
        yield Success<List<ConversationMessage>>(
          List<ConversationMessage>.unmodifiable(messages),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<List<ConversationMessage>>(
        MessagingFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<List<ConversationMessage>>(
        MessagingFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<MessagePage>> loadOlderMessages({
    required String conversationId,
    required String viewerId,
    required MessageCursor cursor,
    int limit = 40,
  }) async {
    try {
      final int safeLimit = limit.clamp(1, 100).toInt();
      final QuerySnapshot<MessageDto> snapshot = await _messages(conversationId)
          .orderBy('sentAt', descending: true)
          .orderBy(FieldPath.documentId, descending: true)
          .startAfter(<Object>[
            Timestamp.fromDate(cursor.sentAt.toUtc()),
            cursor.documentId,
          ])
          .limit(safeLimit)
          .get();
      final Map<String, Set<String>> reactions = await _viewerReactions(
        viewerId,
        conversationId,
        snapshot.docs.map((QueryDocumentSnapshot<MessageDto> item) => item.id),
      );
      final Map<String, Set<String>> viewOnceClaims =
          await _viewerViewOnceClaims(
            viewerId,
            conversationId,
            snapshot.docs.map(
              (QueryDocumentSnapshot<MessageDto> item) => item.data(),
            ),
          );
      final List<ConversationMessage> items =
          snapshot.docs
              .map(
                (QueryDocumentSnapshot<MessageDto> item) =>
                    item.data().toDomain(
                      viewerReactions: reactions[item.id] ?? const <String>{},
                      consumedViewOnceAttachmentIds:
                          viewOnceClaims[item.id] ?? const <String>{},
                    ),
              )
              .toList(growable: true)
            ..sort(
              (ConversationMessage first, ConversationMessage second) =>
                  first.sentAt.compareTo(second.sentAt),
            );
      final QueryDocumentSnapshot<MessageDto>? last = snapshot.docs.isEmpty
          ? null
          : snapshot.docs.last;
      return Success<MessagePage>(
        MessagePage(
          items: List<ConversationMessage>.unmodifiable(items),
          hasMore: snapshot.docs.length == safeLimit,
          nextCursor: last == null
              ? null
              : MessageCursor(sentAt: last.data().sentAt, documentId: last.id),
        ),
      );
    } on FirebaseException catch (error) {
      return FailureResult<MessagePage>(
        MessagingFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      return FailureResult<MessagePage>(
        MessagingFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<String>> createDirectConversation(String targetUserId) async {
    try {
      final Map<String, dynamic> data = await _call(
        'createDirectConversation',
        <String, Object?>{'targetUserId': targetUserId},
      );
      return Success<String>(_requiredString(data, 'conversationId'));
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<String>(MessagingFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<String>(MessagingFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<String?>> createMessageRequest(String targetUserId) async {
    try {
      final Map<String, dynamic> data = await _call(
        'createMessageRequest',
        <String, Object?>{'targetUserId': targetUserId},
      );
      final Object? conversationId = data['conversationId'];
      if (conversationId is String && conversationId.trim().isNotEmpty) {
        return Success<String?>(conversationId.trim());
      }
      return const Success<String?>(null);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<String?>(
        MessagingFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<String?>(MessagingFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> cancelMessageRequest(String targetUserId) => _voidCall(
    'cancelMessageRequest',
    <String, Object?>{'targetUserId': targetUserId},
  );

  @override
  Future<Result<String?>> respondToMessageRequest({
    required String requesterId,
    required String decision,
  }) async {
    try {
      final Map<String, dynamic> data = await _call(
        'respondToMessageRequest',
        <String, Object?>{'requesterId': requesterId, 'decision': decision},
      );
      final Object? conversationId = data['conversationId'];
      if (conversationId is String && conversationId.trim().isNotEmpty) {
        return Success<String?>(conversationId.trim());
      }
      return const Success<String?>(null);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<String?>(
        MessagingFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<String?>(MessagingFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<String>> createGroupConversation({
    required String title,
    required List<String> memberIds,
  }) async {
    try {
      final Map<String, dynamic> data = await _call(
        'createGroupConversation',
        <String, Object?>{'title': title, 'memberIds': memberIds},
      );
      return Success<String>(_requiredString(data, 'conversationId'));
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<String>(MessagingFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<String>(MessagingFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> updateGroup({
    required String conversationId,
    String? title,
    String? avatarUrl,
    String? avatarStoragePath,
    List<String> addMemberIds = const <String>[],
    List<String> removeMemberIds = const <String>[],
  }) async {
    return _voidCall('updateGroupConversation', <String, Object?>{
      'conversationId': conversationId,
      'title': ?title,
      'avatarUrl': ?avatarUrl,
      'avatarStoragePath': ?avatarStoragePath,
      'addMemberIds': addMemberIds,
      'removeMemberIds': removeMemberIds,
    });
  }

  @override
  Future<Result<void>> leaveConversation(String conversationId) => _voidCall(
    'leaveConversation',
    <String, Object?>{'conversationId': conversationId},
  );

  @override
  Future<Result<ConversationMessage>> sendMessage(
    SendMessageRequest request,
  ) async {
    try {
      final Map<String, dynamic> data =
          await _call('sendMessage', <String, Object?>{
            'conversationId': request.conversationId,
            'clientMessageId': request.clientMessageId,
            'text': request.text,
            'mediaMode': request.mediaMode.wireValue,
            'attachments': request.attachments
                .map((item) => item.toRequestMap())
                .toList(growable: false),
            if (request.replyToMessageId != null)
              'replyToMessageId': request.replyToMessageId,
          });
      final String messageId = _requiredString(data, 'messageId');
      final DocumentSnapshot<MessageDto> snapshot = await _messages(
        request.conversationId,
      ).doc(messageId).get();
      final MessageDto? message = snapshot.data();
      if (message == null) {
        throw StateError('The sent message could not be loaded.');
      }
      return Success<ConversationMessage>(message.toDomain());
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<ConversationMessage>(
        MessagingFailureMapper.fromFunctions(error),
      );
    } on FirebaseException catch (error) {
      return FailureResult<ConversationMessage>(
        MessagingFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      return FailureResult<ConversationMessage>(
        MessagingFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<void>> editMessage({
    required String conversationId,
    required String messageId,
    required String text,
  }) => _voidCall('editMessage', <String, Object?>{
    'conversationId': conversationId,
    'messageId': messageId,
    'text': text,
  });

  @override
  Future<Result<void>> deleteMessage({
    required String conversationId,
    required String messageId,
  }) => _voidCall('deleteMessage', <String, Object?>{
    'conversationId': conversationId,
    'messageId': messageId,
  });

  @override
  Future<Result<void>> toggleReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) => _voidCall('toggleMessageReaction', <String, Object?>{
    'conversationId': conversationId,
    'messageId': messageId,
    'emoji': emoji,
  });

  @override
  Future<Result<void>> markRead({
    required String conversationId,
    required String messageId,
    required DateTime messageSentAt,
  }) => _voidCall('markConversationRead', <String, Object?>{
    'conversationId': conversationId,
    'messageId': messageId,
    'messageSentAt': messageSentAt.toUtc().toIso8601String(),
  });

  @override
  Future<Result<void>> updatePreferences(
    ConversationPreferencesUpdate update,
  ) => _voidCall('updateConversationPreferences', <String, Object?>{
    'conversationId': update.conversationId,
    if (update.mutedUntil != null)
      'mutedUntil': update.mutedUntil!.toUtc().toIso8601String(),
    if (update.notificationsEnabled != null)
      'notificationsEnabled': update.notificationsEnabled,
    if (update.archived != null) 'archived': update.archived,
  });

  @override
  Future<Result<void>> reportMessage({
    required String conversationId,
    required String messageId,
    required String reason,
    String details = '',
  }) => _voidCall('reportMessage', <String, Object?>{
    'conversationId': conversationId,
    'messageId': messageId,
    'reason': reason,
    'details': details,
  });

  CollectionReference<ConversationSummaryDto> _inbox(String uid) => _firestore
      .collection(FirestoreCollections.users)
      .doc(uid)
      .collection(FirestoreCollections.conversationInbox)
      .withConverter<ConversationSummaryDto>(
        fromFirestore: ConversationSummaryDto.fromFirestore,
        toFirestore: (_, unused) => throw UnsupportedError('Server managed.'),
      );

  CollectionReference<ConversationDto> get _conversations => _firestore
      .collection(FirestoreCollections.conversations)
      .withConverter<ConversationDto>(
        fromFirestore: ConversationDto.fromFirestore,
        toFirestore: (_, unused) => throw UnsupportedError('Server managed.'),
      );

  CollectionReference<ConversationMemberDto> _members(String conversationId) =>
      _firestore
          .collection(FirestoreCollections.conversations)
          .doc(conversationId)
          .collection(FirestoreCollections.members)
          .withConverter<ConversationMemberDto>(
            fromFirestore: ConversationMemberDto.fromFirestore,
            toFirestore: (_, unused) =>
                throw UnsupportedError('Server managed.'),
          );

  CollectionReference<MessageDto> _messages(String conversationId) => _firestore
      .collection(FirestoreCollections.conversations)
      .doc(conversationId)
      .collection(FirestoreCollections.messages)
      .withConverter<MessageDto>(
        fromFirestore: MessageDto.fromFirestore,
        toFirestore: (_, unused) => throw UnsupportedError('Server managed.'),
      );

  Future<Map<String, Set<String>>> _viewerReactions(
    String viewerId,
    String conversationId,
    Iterable<String> messageIds,
  ) async {
    final List<String> ids = messageIds.toSet().toList(growable: false);
    if (ids.isEmpty) {
      return const <String, Set<String>>{};
    }
    final Map<String, Set<String>> result = <String, Set<String>>{};
    try {
    for (int start = 0; start < ids.length; start += 30) {
      final List<String> slice = ids.sublist(
        start,
        (start + 30).clamp(0, ids.length).toInt(),
      );
      final List<String> keys = slice
          .map((String messageId) => '$conversationId--$messageId')
          .toList(growable: false);
        // Rules require request.query.limit <= 100. A whereIn without limit is
        // denied (permission-denied) even for the document owner — which made
        // inbox previews work while opening the same thread failed.
      final QuerySnapshot<FirestoreMap> snapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(viewerId)
          .collection(FirestoreCollections.messageReactions)
          .where(FieldPath.documentId, whereIn: keys)
            .limit(keys.length.clamp(1, 100).toInt())
          .get();
      for (final QueryDocumentSnapshot<FirestoreMap> document
          in snapshot.docs) {
        final String messageId = document.data()['messageId'] as String? ?? '';
        final List<String> emojis = FirestoreParser.stringList(
          document.data(),
          'emojis',
        );
        if (messageId.isNotEmpty) {
          result[messageId] = emojis.toSet();
        }
      }
      }
    } on FirebaseException {
      // Reaction hydration is best-effort; never block message history.
      return result;
    }
    return result;
  }

  /// Loads the viewer's own view-once claim docs so UI can show consumed state.
  Future<Map<String, Set<String>>> _viewerViewOnceClaims(
    String viewerId,
    String conversationId,
    Iterable<MessageDto> messages,
  ) async {
    final List<MapEntry<String, String>> targets = <MapEntry<String, String>>[];
    for (final MessageDto message in messages) {
      for (final MessageAttachmentDto attachment in message.attachments) {
        if (attachment.mediaMode == 'view_once' &&
            !attachment.viewOnceConsumed) {
          targets.add(MapEntry<String, String>(message.id, attachment.id));
        }
      }
    }
    if (targets.isEmpty) {
      return const <String, Set<String>>{};
    }
    final Map<String, Set<String>> result = <String, Set<String>>{};
    final CollectionReference<MessageDto> messagesRef = _messages(
      conversationId,
    );
    await Future.wait(
      targets.map((MapEntry<String, String> record) async {
        final String messageId = record.key;
        final String attachmentId = record.value;
        final String claimId = '$viewerId--$attachmentId';
        try {
          final DocumentSnapshot<FirestoreMap> claim = await messagesRef
              .doc(messageId)
              .collection('view_once_claims')
              .doc(claimId)
              .get();
          if (claim.exists) {
            result.putIfAbsent(messageId, () => <String>{}).add(attachmentId);
          }
        } on FirebaseException {
          // Claim reads are best-effort; missing permission should not fail
          // the message stream.
        }
      }),
    );
    return result;
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> payload,
  ) async {
    if (_auth.currentUser == null) {
      throw StateError('A signed-in account is required.');
    }
    final HttpsCallableResult<dynamic> response = await _functions
        .httpsCallable(name)
        .call<dynamic>(payload);
    if (response.data is! Map) {
      throw FormatException('$name returned an invalid response.');
    }
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Result<void>> _voidCall(
    String name,
    Map<String, Object?> payload,
  ) async {
    try {
      await _call(name, payload);
      return const Success<void>(null);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<void>(MessagingFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<void>(MessagingFailureMapper.unexpected(error));
    }
  }

  static String _requiredString(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    throw FormatException('Messaging response is missing $field.');
  }

  static Failure _failure(Object error) => error is FirebaseException
      ? MessagingFailureMapper.fromFirestore(error)
      : MessagingFailureMapper.unexpected(error);
}
