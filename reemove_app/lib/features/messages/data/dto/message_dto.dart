import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/firestore_parser.dart';
import 'messaging_user_dto.dart';

class MessageAttachmentDto {
  const MessageAttachmentDto({
    required this.id,
    required this.kind,
    required this.storagePath,
    required this.contentType,
    required this.sizeBytes,
    required this.processingState,
    this.downloadUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.durationMs,
    this.mediaMode = 'normal',
    this.viewOnceConsumed = false,
  });

  factory MessageAttachmentDto.fromMap(FirestoreMap data) =>
      MessageAttachmentDto(
        id: FirestoreParser.string(data, 'id'),
        kind: FirestoreParser.string(data, 'kind', fallback: 'image'),
        storagePath: FirestoreParser.string(data, 'storagePath'),
        downloadUrl: FirestoreParser.nullableString(data, 'downloadUrl'),
        thumbnailUrl: FirestoreParser.nullableString(data, 'thumbnailUrl'),
        contentType: FirestoreParser.string(data, 'contentType'),
        sizeBytes: FirestoreParser.integer(data, 'sizeBytes', fallback: 0),
        width: FirestoreParser.nullableInteger(data, 'width'),
        height: FirestoreParser.nullableInteger(data, 'height'),
        durationMs: FirestoreParser.nullableInteger(data, 'durationMs'),
        processingState: FirestoreParser.string(
          data,
          'processingState',
          fallback: 'ready',
        ),
        mediaMode: FirestoreParser.string(data, 'mediaMode', fallback: 'normal'),
        viewOnceConsumed: FirestoreParser.boolean(
          data,
          'viewOnceConsumed',
          fallback: false,
        ),
      );

  final String id;
  final String kind;
  final String storagePath;
  final String? downloadUrl;
  final String? thumbnailUrl;
  final String contentType;
  final int sizeBytes;
  final int? width;
  final int? height;
  final int? durationMs;
  final String processingState;
  final String mediaMode;
  final bool viewOnceConsumed;
}

class MessageReplyPreviewDto {
  const MessageReplyPreviewDto({
    required this.messageId,
    required this.senderId,
    required this.senderDisplayName,
    required this.kind,
    required this.preview,
  });

  factory MessageReplyPreviewDto.fromMap(FirestoreMap data) =>
      MessageReplyPreviewDto(
        messageId: FirestoreParser.string(data, 'messageId'),
        senderId: FirestoreParser.string(data, 'senderId'),
        senderDisplayName: FirestoreParser.string(data, 'senderDisplayName'),
        kind: FirestoreParser.string(data, 'kind', fallback: 'text'),
        preview: FirestoreParser.string(data, 'preview', fallback: ''),
      );

  final String messageId;
  final String senderId;
  final String senderDisplayName;
  final String kind;
  final String preview;
}

class MessageDto {
  const MessageDto({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.kind,
    required this.text,
    required this.attachments,
    required this.reactionCounts,
    required this.sentAt,
    required this.isDeleted,
    this.replyTo,
    this.editedAt,
  });

  factory MessageDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap data = snapshot.data() ?? const <String, dynamic>{};
    final FirestoreMap? reply = data['replyTo'] is Map
        ? (data['replyTo'] as Map).cast<String, dynamic>()
        : null;
    final FirestoreMap counts = data['reactionCounts'] is Map
        ? (data['reactionCounts'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    return MessageDto(
      id: snapshot.id,
      conversationId: FirestoreParser.string(data, 'conversationId'),
      sender: MessagingUserDto.fromMap(
        FirestoreParser.map(data, 'senderSnapshot'),
      ),
      kind: FirestoreParser.string(data, 'kind', fallback: 'text'),
      text: FirestoreParser.string(data, 'text', fallback: ''),
      attachments: FirestoreParser.mapList(
        data,
        'attachments',
      ).map(MessageAttachmentDto.fromMap).toList(growable: false),
      replyTo: reply == null ? null : MessageReplyPreviewDto.fromMap(reply),
      reactionCounts: counts.map<String, int>(
        (String key, dynamic value) =>
            MapEntry<String, int>(key, value is num ? value.toInt() : 0),
      ),
      sentAt: FirestoreParser.dateTime(data, 'sentAt'),
      editedAt: FirestoreParser.nullableDateTime(data, 'editedAt'),
      isDeleted: FirestoreParser.boolean(data, 'isDeleted', fallback: false),
    );
  }

  final String id;
  final String conversationId;
  final MessagingUserDto sender;
  final String kind;
  final String text;
  final List<MessageAttachmentDto> attachments;
  final MessageReplyPreviewDto? replyTo;
  final Map<String, int> reactionCounts;
  final DateTime sentAt;
  final DateTime? editedAt;
  final bool isDeleted;
}
