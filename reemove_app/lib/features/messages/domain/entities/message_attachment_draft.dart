import 'dart:typed_data';

import 'message.dart';

class MessageAttachmentDraft {
  const MessageAttachmentDraft({
    required this.id,
    required this.bytes,
    required this.fileName,
    required this.contentType,
    required this.kind,
  });

  final String id;
  final Uint8List bytes;
  final String fileName;
  final String contentType;
  final MessageKind kind;
}

class UploadedMessageAttachment {
  const UploadedMessageAttachment({
    required this.id,
    required this.storagePath,
    required this.contentType,
    required this.sizeBytes,
    required this.kind,
  });

  final String id;
  final String storagePath;
  final String contentType;
  final int sizeBytes;
  final MessageKind kind;

  Map<String, Object?> toRequestMap() => <String, Object?>{
    'id': id,
    'storagePath': storagePath,
    'contentType': contentType,
    'sizeBytes': sizeBytes,
    'kind': kind.name,
  };
}
