import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/avatar_asset.dart';
import '../../domain/services/avatar_picker_service.dart';

class PlatformAvatarPickerService implements AvatarPickerService {
  PlatformAvatarPickerService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Result<AvatarUploadSource?>> pickFromGallery() =>
      _pick(ImageSource.gallery);

  @override
  Future<Result<AvatarUploadSource?>> pickFromCamera() =>
      _pick(ImageSource.camera);

  @override
  Future<Result<AvatarUploadSource?>> recoverLostSelection() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty) {
        return const Success<AvatarUploadSource?>(null);
      }
      final List<XFile>? files = response.files;
      final XFile? file = files == null || files.isEmpty ? null : files.first;
      if (file == null) {
        return FailureResult<AvatarUploadSource?>(
          Failure(
            message:
                response.exception?.message ??
                'The selected avatar could not be recovered.',
            code: 'avatar/lost-data',
          ),
        );
      }
      return _read(file);
    } catch (error) {
      return FailureResult<AvatarUploadSource?>(_failure(error));
    }
  }

  Future<Result<AvatarUploadSource?>> _pick(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (file == null) {
        return const Success<AvatarUploadSource?>(null);
      }
      return _read(file);
    } catch (error) {
      return FailureResult<AvatarUploadSource?>(_failure(error));
    }
  }

  Future<Result<AvatarUploadSource?>> _read(XFile file) async {
    final List<int> bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length >= 10 * 1024 * 1024) {
      return const FailureResult<AvatarUploadSource?>(
        Failure(
          message: 'Choose an image smaller than 10 MB.',
          code: 'avatar/invalid-size',
        ),
      );
    }
    final String contentType = file.mimeType ?? _contentTypeFor(file.name);
    if (!contentType.startsWith('image/')) {
      return const FailureResult<AvatarUploadSource?>(
        Failure(
          message: 'Choose a JPG, PNG, WEBP, or HEIC image.',
          code: 'avatar/invalid-type',
        ),
      );
    }
    return Success<AvatarUploadSource?>(
      AvatarUploadSource(
        bytes: Uint8List.fromList(bytes),
        filename: file.name,
        contentType: contentType,
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
    return 'image/jpeg';
  }

  static Failure _failure(Object error) => Failure(
    message: 'ReeMove could not open the image picker.',
    code: 'avatar/picker-failed',
    debugMessage: error.toString(),
    cause: error,
  );
}
