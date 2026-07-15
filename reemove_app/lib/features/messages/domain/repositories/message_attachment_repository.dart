import '../../../../core/result/result.dart';
import '../entities/message_attachment_draft.dart';

abstract interface class MessageAttachmentRepository {
  Future<Result<UploadedMessageAttachment>> upload({
    required String userId,
    required String conversationId,
    required String messageId,
    required MessageAttachmentDraft draft,
    void Function(double progress)? onProgress,
  });

  Future<Result<String>> resolveDownloadUrl(String storagePath);

  Future<Result<void>> delete({
    required String userId,
    required String conversationId,
    required String storagePath,
  });
}
