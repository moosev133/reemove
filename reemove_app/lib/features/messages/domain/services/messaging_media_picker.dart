import '../../../../core/result/result.dart';
import '../entities/message_attachment_draft.dart';

abstract interface class MessagingMediaPicker {
  Future<Result<MessageAttachmentDraft?>> pickImage();
  Future<Result<MessageAttachmentDraft?>> pickVideo();
}
