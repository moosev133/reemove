import 'dart:typed_data';

import '../../../groups/domain/entities/group_enums.dart';
import 'message.dart';

class MessageAttachmentDraft {
  const MessageAttachmentDraft({
    required this.id,
    required this.bytes,
    required this.fileName,
    required this.contentType,
    required this.kind,
    this.mediaMode = GroupMediaMode.normal,
  });

  final String id;
  final Uint8List bytes;
  final String fileName;
  final String contentType;
  final MessageKind kind;
  final GroupMediaMode mediaMode;
}

class UploadedMessageAttachment {
  const UploadedMessageAttachment({
    required this.id,
    required this.storagePath,
    required this.contentType,
    required this.sizeBytes,
    required this.kind,
    this.mediaMode = GroupMediaMode.normal,
  });

  final String id;
  final String storagePath;
  final String contentType;
  final int sizeBytes;
  final MessageKind kind;
  final GroupMediaMode mediaMode;

  Map<String, Object?> toRequestMap() => <String, Object?>{
    'id': id,
    'storagePath': storagePath,
    'contentType': contentType,
    'sizeBytes': sizeBytes,
    'kind': kind.name,
    'mediaMode': mediaMode.wireValue,
  };
}
