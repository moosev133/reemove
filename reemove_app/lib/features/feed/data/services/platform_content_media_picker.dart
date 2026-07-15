import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/content_draft.dart';
import '../../domain/services/content_media_picker.dart';
import '../../domain/value_objects/content_limits.dart';

class PlatformContentMediaPicker implements ContentMediaPicker {
  PlatformContentMediaPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Result<List<DraftMediaSelection>>> pickImages({int limit = 10}) async {
    try {
      final List<XFile> files = await _picker.pickMultiImage(
        imageQuality: 92,
        maxWidth: 2160,
      );
      if (files.isEmpty) {
        return const Success<List<DraftMediaSelection>>(
          <DraftMediaSelection>[],
        );
      }
      final List<DraftMediaSelection> selections = <DraftMediaSelection>[];
      for (final XFile file in files.take(limit)) {
        final Result<DraftMediaSelection> result = await _selectionFor(
          file,
          DraftMediaKind.image,
        );
        final DraftMediaSelection? selection = result.when(
          success: (DraftMediaSelection value) => value,
          failure: (_) => null,
        );
        if (selection != null) {
          selections.add(selection);
        }
      }
      if (selections.isEmpty) {
        return const FailureResult<List<DraftMediaSelection>>(
          Failure(
            message: 'Choose supported images smaller than 15 MB each.',
            code: 'content/invalid-images',
          ),
        );
      }
      return Success<List<DraftMediaSelection>>(selections);
    } catch (error) {
      return FailureResult<List<DraftMediaSelection>>(_failure(error));
    }
  }

  @override
  Future<Result<DraftMediaSelection?>> pickVideo() async {
    try {
      final XFile? file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: ContentLimits.maxReelDuration,
      );
      if (file == null) {
        return const Success<DraftMediaSelection?>(null);
      }
      final Result<DraftMediaSelection> result = await _selectionFor(
        file,
        DraftMediaKind.video,
      );
      return result.when<Result<DraftMediaSelection?>>(
        success: (DraftMediaSelection value) =>
            Success<DraftMediaSelection?>(value),
        failure: (Failure failure) =>
            FailureResult<DraftMediaSelection?>(failure),
      );
    } catch (error) {
      return FailureResult<DraftMediaSelection?>(_failure(error));
    }
  }

  @override
  Future<Result<List<DraftMediaSelection>>> recoverLostSelections() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty) {
        return const Success<List<DraftMediaSelection>>(
          <DraftMediaSelection>[],
        );
      }
      final List<XFile> files = response.files ?? const <XFile>[];
      final List<DraftMediaSelection> recovered = <DraftMediaSelection>[];
      for (final XFile file in files) {
        final DraftMediaKind kind =
            _contentTypeFor(file.name).startsWith('video/')
            ? DraftMediaKind.video
            : DraftMediaKind.image;
        final Result<DraftMediaSelection> result = await _selectionFor(
          file,
          kind,
        );
        result.when<void>(success: recovered.add, failure: (_) {});
      }
      if (recovered.isEmpty && response.exception != null) {
        return FailureResult<List<DraftMediaSelection>>(
          Failure(
            message: response.exception!.message ?? 'Unable to recover media.',
            code: 'content/lost-data',
          ),
        );
      }
      return Success<List<DraftMediaSelection>>(recovered);
    } catch (error) {
      return FailureResult<List<DraftMediaSelection>>(_failure(error));
    }
  }

  Future<Result<DraftMediaSelection>> _selectionFor(
    XFile file,
    DraftMediaKind kind,
  ) async {
    final int sizeBytes = await file.length();
    final int maxBytes = kind == DraftMediaKind.video
        ? ContentLimits.maxVideoBytes
        : ContentLimits.maxPostImageBytes;
    if (sizeBytes <= 0 || sizeBytes > maxBytes) {
      return FailureResult<DraftMediaSelection>(
        Failure(
          message: kind == DraftMediaKind.video
              ? 'Choose a video smaller than 150 MB.'
              : 'Choose an image smaller than 15 MB.',
          code: 'content/invalid-size',
        ),
      );
    }
    final String contentType = file.mimeType ?? _contentTypeFor(file.name);
    final bool validType = kind == DraftMediaKind.video
        ? contentType.startsWith('video/')
        : contentType.startsWith('image/');
    if (!validType) {
      return const FailureResult<DraftMediaSelection>(
        Failure(
          message: 'This media format is not supported.',
          code: 'content/invalid-type',
        ),
      );
    }
    return Success<DraftMediaSelection>(
      DraftMediaSelection(
        localPath: file.path,
        name: file.name,
        kind: kind,
        contentType: contentType,
        sizeBytes: sizeBytes,
      ),
    );
  }

  static String _contentTypeFor(String filename) {
    final String lower = filename.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return 'image/heic';
    }
    if (lower.endsWith('.mp4')) {
      return 'video/mp4';
    }
    if (lower.endsWith('.mov')) {
      return 'video/quicktime';
    }
    if (lower.endsWith('.webm')) {
      return 'video/webm';
    }
    return 'image/jpeg';
  }

  static Failure _failure(Object error) => Failure(
    message: 'ReeMove could not open your media library.',
    code: 'content/picker-failed',
    debugMessage: error.toString(),
    cause: error,
  );
}
