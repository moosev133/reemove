import 'dart:typed_data';

import '../../../../core/errors/failure.dart';
import '../entities/profile_image.dart';

/// Client-side validation for verification evidence images.
///
/// Accepts PNG and JPEG only for this milestone. PDF and other formats are
/// rejected with an explicit message. Magic-byte checks prevent renamed
/// non-images from passing solely on extension/MIME.
abstract final class VerificationEvidenceValidator {
  static const int maxBytes = 15 * 1024 * 1024;

  static const Set<String> allowedContentTypes = <String>{
    'image/png',
    'image/jpeg',
    'image/jpg',
  };

  static Failure? validateSource(ProfileImageSource source) {
    return validateBytes(
      bytes: source.bytes,
      filename: source.filename,
      declaredContentType: source.contentType,
    );
  }

  static Failure? validateBytes({
    required Uint8List bytes,
    required String filename,
    String? declaredContentType,
  }) {
    final String lowerName = filename.trim().toLowerCase();
    if (lowerName.endsWith('.pdf') ||
        (declaredContentType ?? '').toLowerCase().contains('pdf')) {
      return const Failure(
        message:
            'PDF documents are not supported yet. Upload a PNG or JPEG image of your certificate.',
        code: 'profile/verification-pdf-unsupported',
      );
    }
    if (bytes.isEmpty) {
      return const Failure(
        message: 'The selected file is empty.',
        code: 'profile/verification-empty',
      );
    }
    if (bytes.lengthInBytes > maxBytes) {
      return const Failure(
        message: 'Choose an evidence image smaller than 15 MB.',
        code: 'profile/verification-size',
      );
    }
    if (_looksLikePdf(bytes)) {
      return const Failure(
        message:
            'PDF documents are not supported yet. Upload a PNG or JPEG image of your certificate.',
        code: 'profile/verification-pdf-unsupported',
      );
    }

    final String? magicType = detectImageContentType(bytes);
    if (magicType == null) {
      return const Failure(
        message:
            'That file is not a valid PNG or JPEG image. Choose a supported image file.',
        code: 'profile/verification-magic',
      );
    }

    final String normalizedDeclared = _normalizeContentType(declaredContentType);
    if (normalizedDeclared.isNotEmpty &&
        !allowedContentTypes.contains(normalizedDeclared) &&
        normalizedDeclared != 'application/octet-stream') {
      return Failure(
        message:
            'Unsupported file type ($normalizedDeclared). Upload a PNG or JPEG image.',
        code: 'profile/verification-type',
      );
    }
    if (normalizedDeclared == 'application/octet-stream' ||
        normalizedDeclared.isEmpty) {
      // Trust magic bytes when browsers omit or genericize MIME.
      return null;
    }
    if (normalizedDeclared != magicType &&
        !(normalizedDeclared == 'image/jpg' && magicType == 'image/jpeg')) {
      return const Failure(
        message:
            'The file contents do not match a PNG or JPEG image. Choose a supported image file.',
        code: 'profile/verification-mismatch',
      );
    }
    return null;
  }

  static String resolveContentType({
    required Uint8List bytes,
    String? declaredContentType,
    String? filename,
  }) {
    final String? magic = detectImageContentType(bytes);
    if (magic != null) {
      return magic;
    }
    final String normalized = _normalizeContentType(declaredContentType);
    if (allowedContentTypes.contains(normalized)) {
      return normalized == 'image/jpg' ? 'image/jpeg' : normalized;
    }
    final String lower = (filename ?? '').toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return normalized.isEmpty ? 'application/octet-stream' : normalized;
  }

  static String? detectImageContentType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    return null;
  }

  static bool _looksLikePdf(Uint8List bytes) {
    if (bytes.length < 5) {
      return false;
    }
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D; // %PDF-
  }

  static String _normalizeContentType(String? value) {
    if (value == null) {
      return '';
    }
    return value.trim().toLowerCase().split(';').first.trim();
  }
}
