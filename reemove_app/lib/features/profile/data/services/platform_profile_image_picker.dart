import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/profile_image.dart';
import '../../domain/services/profile_image_picker.dart';

class PlatformProfileImagePicker implements ProfileImagePicker {
  PlatformProfileImagePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Result<ProfileImageSource?>> pick(ProfileImageKind kind) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: kind == ProfileImageKind.avatar ? 1600 : 2400,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      return Success<ProfileImageSource?>(
        file == null ? null : await _source(file),
      );
    } catch (error) {
      return FailureResult<ProfileImageSource?>(
        Failure(
          message: 'The image picker could not be opened.',
          code: 'profile/image-picker',
          debugMessage: error.toString(),
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<ProfileImageSource?>> recoverLostSelection() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty ||
          response.files == null ||
          response.files!.isEmpty) {
        return const Success<ProfileImageSource?>(null);
      }
      return Success<ProfileImageSource?>(await _source(response.files!.first));
    } catch (error) {
      return FailureResult<ProfileImageSource?>(
        Failure(
          message: 'The selected image could not be recovered.',
          code: 'profile/image-recovery',
          debugMessage: error.toString(),
          cause: error,
        ),
      );
    }
  }

  static Future<ProfileImageSource> _source(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 15 * 1024 * 1024) {
      throw StateError('Choose an image smaller than 15 MB.');
    }
    final String contentType = file.mimeType ?? _contentType(file.name);
    if (!contentType.startsWith('image/')) {
      throw StateError('Choose a supported image file.');
    }
    return ProfileImageSource(
      bytes: bytes,
      filename: file.name,
      contentType: contentType,
    );
  }

  static String _contentType(String filename) {
    final String extension = filename.toLowerCase().split('.').last;
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      _ => 'image/jpeg',
    };
  }
}
