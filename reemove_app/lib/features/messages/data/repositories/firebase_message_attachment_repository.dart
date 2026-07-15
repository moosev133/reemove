import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/message_attachment_draft.dart';
import '../../domain/repositories/message_attachment_repository.dart';
import '../services/messaging_failure_mapper.dart';

class FirebaseMessageAttachmentRepository
    implements MessageAttachmentRepository {
  const FirebaseMessageAttachmentRepository(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<Result<UploadedMessageAttachment>> upload({
    required String userId,
    required String conversationId,
    required String messageId,
    required MessageAttachmentDraft draft,
    void Function(double progress)? onProgress,
  }) async {
    final String safeName = draft.fileName.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    final Reference target = _storage.ref(
      'messages/$conversationId/$messageId/${draft.id}/$safeName',
    );
    StreamSubscription<TaskSnapshot>? progressSubscription;
    try {
      final UploadTask task = target.putData(
        draft.bytes,
        SettableMetadata(
          contentType: draft.contentType,
          cacheControl: 'private,max-age=3600',
          customMetadata: <String, String>{
            'ownerId': userId,
            'conversationId': conversationId,
            'messageId': messageId,
            'assetId': draft.id,
            'kind': draft.kind.name,
            'schemaVersion': '1',
          },
        ),
      );
      if (onProgress != null) {
        progressSubscription = task.snapshotEvents.listen((
          TaskSnapshot snapshot,
        ) {
          final int total = snapshot.totalBytes;
          onProgress(total <= 0 ? 0 : snapshot.bytesTransferred / total);
        });
      }
      await task;
      onProgress?.call(1);
      return Success<UploadedMessageAttachment>(
        UploadedMessageAttachment(
          id: draft.id,
          storagePath: target.fullPath,
          contentType: draft.contentType,
          sizeBytes: draft.bytes.lengthInBytes,
          kind: draft.kind,
        ),
      );
    } on FirebaseException catch (error) {
      return FailureResult<UploadedMessageAttachment>(
        MessagingFailureMapper.fromStorage(error),
      );
    } on Object catch (error) {
      return FailureResult<UploadedMessageAttachment>(
        MessagingFailureMapper.unexpected(error),
      );
    } finally {
      await progressSubscription?.cancel();
    }
  }

  @override
  Future<Result<String>> resolveDownloadUrl(String storagePath) async {
    try {
      return Success<String>(await _storage.ref(storagePath).getDownloadURL());
    } on FirebaseException catch (error) {
      return FailureResult<String>(MessagingFailureMapper.fromStorage(error));
    } on Object catch (error) {
      return FailureResult<String>(MessagingFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> delete({
    required String userId,
    required String conversationId,
    required String storagePath,
  }) async {
    final String prefix = 'messages/$conversationId/';
    if (!storagePath.startsWith(prefix)) {
      return FailureResult<void>(
        MessagingFailureMapper.unexpected(
          ArgumentError(
            'Attachment path does not belong to this conversation.',
          ),
        ),
      );
    }
    try {
      await _storage.ref(storagePath).delete();
      return const Success<void>(null);
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return const Success<void>(null);
      }
      return FailureResult<void>(MessagingFailureMapper.fromStorage(error));
    } on Object catch (error) {
      return FailureResult<void>(MessagingFailureMapper.unexpected(error));
    }
  }
}
