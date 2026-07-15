import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/message_attachment_draft.dart';
import '../../domain/services/messaging_media_picker.dart';

class PlatformMessagingMediaPicker implements MessagingMediaPicker {
  PlatformMessagingMediaPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Result<MessageAttachmentDraft?>> pickImage() => _pick(
    kind: MessageKind.image,
    source: () => _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 4096,
    ),
    maxBytes: 15 * 1024 * 1024,
  );

  @override
  Future<Result<MessageAttachmentDraft?>> pickVideo() => _pick(
    kind: MessageKind.video,
    source: () => _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    ),
    maxBytes: 100 * 1024 * 1024,
  );

  Future<Result<MessageAttachmentDraft?>> _pick({
    required MessageKind kind,
    required Future<XFile?> Function() source,
    required int maxBytes,
  }) async {
    try {
      final XFile? file = await source();
      if (file == null) {
        return const Success<MessageAttachmentDraft?>(null);
      }
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes <= 0 || bytes.lengthInBytes > maxBytes) {
        return FailureResult<MessageAttachmentDraft?>(
          Failure(
            message: kind == MessageKind.image
                ? 'Choose an image smaller than 15 MB.'
                : 'Choose a video smaller than 100 MB.',
            code: 'messages/attachment-size',
          ),
        );
      }
      final String contentType =
          file.mimeType ??
          (kind == MessageKind.image ? 'image/jpeg' : 'video/mp4');
      return Success<MessageAttachmentDraft?>(
        MessageAttachmentDraft(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          bytes: bytes,
          fileName: file.name,
          contentType: contentType,
          kind: kind,
        ),
      );
    } on Object catch (error) {
      return FailureResult<MessageAttachmentDraft?>(
        Failure(
          message: 'The selected media could not be opened.',
          code: 'messages/media-picker',
          debugMessage: error.toString(),
          cause: error,
        ),
      );
    }
  }
}
