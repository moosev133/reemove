import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/result/result.dart';
import '../../authentication/application/authentication_providers.dart';
import '../../authentication/domain/entities/auth_user.dart';
import '../data/repositories/firebase_message_attachment_repository.dart';
import '../data/repositories/firebase_messaging_device_repository.dart';
import '../data/repositories/firebase_messaging_presence_repository.dart';
import '../data/repositories/firebase_messaging_repository.dart';
import '../data/services/platform_messaging_media_picker.dart';
import '../domain/entities/conversation.dart';
import '../domain/entities/message.dart';
import '../domain/entities/message_attachment_draft.dart';
import '../domain/entities/messaging_action.dart';
import '../domain/entities/messaging_presence.dart';
import '../domain/repositories/message_attachment_repository.dart';
import '../domain/repositories/messaging_device_repository.dart';
import '../domain/repositories/messaging_presence_repository.dart';
import '../domain/repositories/messaging_repository.dart';
import '../domain/services/messaging_media_picker.dart';

export '../../../core/firebase/firebase_providers.dart'
    show firebaseDatabaseProvider;

final Provider<MessagingRepository> messagingRepositoryProvider =
    Provider<MessagingRepository>((Ref ref) {
      return FirebaseMessagingRepository(
        firestore: ref.watch(firebaseFirestoreProvider),
        functions: ref.watch(firebaseFunctionsProvider),
        auth: ref.watch(firebaseAuthProvider),
      );
    });

final Provider<MessagingPresenceRepository>
messagingPresenceRepositoryProvider = Provider<MessagingPresenceRepository>((
  Ref ref,
) {
  return FirebaseMessagingPresenceRepository(
    ref.watch(firebaseDatabaseProvider),
  );
});

final Provider<MessageAttachmentRepository>
messageAttachmentRepositoryProvider = Provider<MessageAttachmentRepository>((
  Ref ref,
) {
  return FirebaseMessageAttachmentRepository(
    ref.watch(firebaseStorageProvider),
  );
});

final Provider<MessagingDeviceRepository> messagingDeviceRepositoryProvider =
    Provider<MessagingDeviceRepository>((Ref ref) {
      return FirebaseMessagingDeviceRepository(
        messaging: ref.watch(firebaseMessagingProvider),
        functions: ref.watch(firebaseFunctionsProvider),
      );
    });

final Provider<MessagingMediaPicker> messagingMediaPickerProvider =
    Provider<MessagingMediaPicker>((Ref ref) => PlatformMessagingMediaPicker());

final messagingInboxProvider =
    StreamProvider.family<List<ConversationSummary>, bool>((
      Ref ref,
      bool archived,
    ) async* {
      final AuthUser? user = await ref.watch(currentAuthUserProvider.future);
      if (user == null) {
        yield const <ConversationSummary>[];
        return;
      }
      await for (final Result<List<ConversationSummary>> result
          in ref
              .watch(messagingRepositoryProvider)
              .watchInbox(userId: user.uid, archived: archived)) {
        yield _value(result);
      }
    });

final StreamProvider<int> messagingUnreadCountProvider = StreamProvider<int>((
  Ref ref,
) async* {
  final FirebaseBootstrapReport report = ref.watch(
    firebaseBootstrapReportProvider,
  );
  if (!report.isReady) {
    yield 0;
    return;
  }
  final AuthUser? user = await ref.watch(currentAuthUserProvider.future);
  if (user == null) {
    yield 0;
    return;
  }
  await for (final Result<int> result
      in ref.watch(messagingRepositoryProvider).watchUnreadCount(user.uid)) {
    yield _value(result);
  }
});

final conversationProvider = StreamProvider.family<Conversation?, String>((
  Ref ref,
  String conversationId,
) async* {
  final AuthUser? user = await ref.watch(currentAuthUserProvider.future);
  if (user == null || conversationId.trim().isEmpty) {
    yield null;
    return;
  }
  await for (final Result<Conversation?> result
      in ref
          .watch(messagingRepositoryProvider)
          .watchConversation(
            conversationId: conversationId,
            viewerId: user.uid,
          )) {
    yield _value(result);
  }
});

final recentMessagesProvider =
    StreamProvider.family<List<ConversationMessage>, String>((
      Ref ref,
      String conversationId,
    ) async* {
      final AuthUser? user = await ref.watch(currentAuthUserProvider.future);
      if (user == null || conversationId.trim().isEmpty) {
        yield const <ConversationMessage>[];
        return;
      }
      await for (final Result<List<ConversationMessage>> result
          in ref
              .watch(messagingRepositoryProvider)
              .watchRecentMessages(
                conversationId: conversationId,
                viewerId: user.uid,
              )) {
        yield _value(result);
      }
    });

final conversationPresenceProvider =
    StreamProvider.family<Map<String, MessagingPresence>, String>((
      Ref ref,
      String conversationId,
    ) async* {
      await for (final Result<Map<String, MessagingPresence>> result
          in ref
              .watch(messagingPresenceRepositoryProvider)
              .watchPresence(conversationId)) {
        yield _value(result);
      }
    });

final conversationTypingProvider =
    StreamProvider.family<List<TypingParticipant>, String>((
      Ref ref,
      String conversationId,
    ) async* {
      await for (final Result<List<TypingParticipant>> result
          in ref
              .watch(messagingPresenceRepositoryProvider)
              .watchTyping(conversationId)) {
        yield _value(result);
      }
    });

final attachmentDownloadUrlProvider = FutureProvider.family<String, String>((
  Ref ref,
  String storagePath,
) async {
  final Result<String> result = await ref
      .watch(messageAttachmentRepositoryProvider)
      .resolveDownloadUrl(storagePath);
  return _value(result);
});

final FutureProvider<void>
messagingDeviceRegistrationProvider = FutureProvider<void>((Ref ref) async {
  final FirebaseBootstrapReport report = ref.watch(
    firebaseBootstrapReportProvider,
  );
  if (!report.isReady) {
    return;
  }
  final AuthUser? user = await ref.watch(currentAuthUserProvider.future);
  if (user == null) {
    return;
  }
  final FirebaseMessaging messaging = ref.watch(firebaseMessagingProvider);
  final NotificationSettings settings = await messaging
      .getNotificationSettings();
  if (settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional) {
    _value(
      await ref.read(messagingDeviceRepositoryProvider).registerCurrentDevice(),
    );
  }
  final StreamSubscription<String> subscription = messaging.onTokenRefresh
      .listen((String _) {
        unawaited(
          ref.read(messagingDeviceRepositoryProvider).registerCurrentDevice(),
        );
      });
  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
});

final StreamProvider<String> messagingOpenedConversationProvider =
    StreamProvider<String>((Ref ref) async* {
      final FirebaseBootstrapReport report = ref.watch(
        firebaseBootstrapReportProvider,
      );
      if (!report.isReady) {
        return;
      }
      final FirebaseMessaging messaging = ref.watch(firebaseMessagingProvider);
      final RemoteMessage? initial = await messaging.getInitialMessage();
      final String? initialId = _conversationId(initial);
      if (initialId != null) {
        yield initialId;
      }
      await for (final RemoteMessage message
          in FirebaseMessaging.onMessageOpenedApp) {
        final String? conversationId = _conversationId(message);
        if (conversationId != null) {
          yield conversationId;
        }
      }
    });

final NotifierProvider<MessagingActionController, AsyncValue<void>>
messagingActionControllerProvider =
    NotifierProvider<MessagingActionController, AsyncValue<void>>(
      MessagingActionController.new,
    );

class MessagingActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue<void>.data(null);

  Future<String?> createDirect(String targetUserId) async {
    return _resultValue(
      () => ref
          .read(messagingRepositoryProvider)
          .createDirectConversation(targetUserId),
    );
  }

  Future<String?> createGroup({
    required String title,
    required List<String> memberIds,
  }) async {
    return _resultValue(
      () => ref
          .read(messagingRepositoryProvider)
          .createGroupConversation(title: title, memberIds: memberIds),
    );
  }

  Future<bool> send({
    required String conversationId,
    required String text,
    List<MessageAttachmentDraft> drafts = const <MessageAttachmentDraft>[],
    String? replyToMessageId,
    void Function(double progress)? onProgress,
  }) async {
    final AuthUser? user = await ref.read(currentAuthUserProvider.future);
    if (user == null) {
      return false;
    }
    final String clientMessageId =
        '${user.uid}_${DateTime.now().microsecondsSinceEpoch}';
    final List<UploadedMessageAttachment> uploaded =
        <UploadedMessageAttachment>[];
    state = const AsyncValue<void>.loading();
    try {
      for (int index = 0; index < drafts.length; index++) {
        final MessageAttachmentDraft draft = drafts[index];
        final Result<UploadedMessageAttachment> result = await ref
            .read(messageAttachmentRepositoryProvider)
            .upload(
              userId: user.uid,
              conversationId: conversationId,
              messageId: clientMessageId,
              draft: draft,
              onProgress: (double itemProgress) {
                final double total = (index + itemProgress) / drafts.length;
                onProgress?.call(total);
              },
            );
        uploaded.add(_value(result));
      }
      final Result<ConversationMessage> result = await ref
          .read(messagingRepositoryProvider)
          .sendMessage(
            SendMessageRequest(
              conversationId: conversationId,
              clientMessageId: clientMessageId,
              text: text,
              attachments: uploaded,
              replyToMessageId: replyToMessageId,
            ),
          );
      _value(result);
      state = const AsyncValue<void>.data(null);
      return true;
    } on Object catch (error, stackTrace) {
      state = AsyncValue<void>.error(error, stackTrace);
      return false;
    }
  }

  Future<bool> toggleReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) => _voidResult(
    () => ref
        .read(messagingRepositoryProvider)
        .toggleReaction(
          conversationId: conversationId,
          messageId: messageId,
          emoji: emoji,
        ),
  );

  Future<bool> markRead(ConversationMessage message) => _voidResult(
    () => ref
        .read(messagingRepositoryProvider)
        .markRead(
          conversationId: message.conversationId,
          messageId: message.id,
          messageSentAt: message.sentAt,
        ),
    silent: true,
  );

  Future<bool> edit({
    required String conversationId,
    required String messageId,
    required String text,
  }) => _voidResult(
    () => ref
        .read(messagingRepositoryProvider)
        .editMessage(
          conversationId: conversationId,
          messageId: messageId,
          text: text,
        ),
  );

  Future<bool> delete({
    required String conversationId,
    required String messageId,
  }) => _voidResult(
    () => ref
        .read(messagingRepositoryProvider)
        .deleteMessage(conversationId: conversationId, messageId: messageId),
  );

  Future<bool> report({
    required String conversationId,
    required String messageId,
    required String reason,
    String details = '',
  }) => _voidResult(
    () => ref
        .read(messagingRepositoryProvider)
        .reportMessage(
          conversationId: conversationId,
          messageId: messageId,
          reason: reason,
          details: details,
        ),
  );

  Future<bool> updatePreferences(ConversationPreferencesUpdate update) =>
      _voidResult(
        () => ref.read(messagingRepositoryProvider).updatePreferences(update),
      );

  Future<bool> updateGroup({
    required String conversationId,
    String? title,
    List<String> addMemberIds = const <String>[],
    List<String> removeMemberIds = const <String>[],
  }) => _voidResult(
    () => ref
        .read(messagingRepositoryProvider)
        .updateGroup(
          conversationId: conversationId,
          title: title,
          addMemberIds: addMemberIds,
          removeMemberIds: removeMemberIds,
        ),
  );

  Future<bool> leaveConversation(String conversationId) => _voidResult(
    () =>
        ref.read(messagingRepositoryProvider).leaveConversation(conversationId),
  );

  Future<bool> setTyping({
    required String conversationId,
    required bool isTyping,
  }) async {
    final AuthUser? user = await ref.read(currentAuthUserProvider.future);
    if (user == null) {
      return false;
    }
    final Result<void> result = await ref
        .read(messagingPresenceRepositoryProvider)
        .setTyping(
          conversationId: conversationId,
          userId: user.uid,
          isTyping: isTyping,
        );
    return result is Success<void>;
  }

  Future<T?> _resultValue<T>(Future<Result<T>> Function() operation) async {
    state = const AsyncValue<void>.loading();
    try {
      final T value = _value(await operation());
      state = const AsyncValue<void>.data(null);
      return value;
    } on Object catch (error, stackTrace) {
      state = AsyncValue<void>.error(error, stackTrace);
      return null;
    }
  }

  Future<bool> _voidResult(
    Future<Result<void>> Function() operation, {
    bool silent = false,
  }) async {
    if (!silent) {
      state = const AsyncValue<void>.loading();
    }
    try {
      _value(await operation());
      if (!silent) {
        state = const AsyncValue<void>.data(null);
      }
      return true;
    } on Object catch (error, stackTrace) {
      if (!silent) {
        state = AsyncValue<void>.error(error, stackTrace);
      }
      return false;
    }
  }
}

T _value<T>(Result<T> result) => result.when<T>(
  success: (T value) => value,
  failure: (Failure failure) => throw StateError(failure.message),
);

String? _conversationId(RemoteMessage? message) {
  if (message == null) {
    return null;
  }
  final Object? value = message.data['conversationId'];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
