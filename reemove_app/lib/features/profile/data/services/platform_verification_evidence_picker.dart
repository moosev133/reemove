import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/debug/staging_diagnostics.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/profile_image.dart';
import '../../domain/services/verification_evidence_validator.dart';

/// Phases reported while the user picks verification evidence.
///
/// No timeout is applied during [choosingFile]; timeouts start only after a
/// file reference is returned (e.g. while reading bytes).
enum VerificationEvidencePickPhase {
  choosingFile,
  readingFile,
  validating,
}

/// Picks verification evidence images without recompression so PNG magic bytes
/// and declared MIME stay aligned with Storage rules.
class PlatformVerificationEvidencePicker {
  PlatformVerificationEvidencePicker({
    ImagePicker? picker,
    Future<XFile?> Function()? openFileOverride,
    Future<Uint8List> Function(XFile file)? readBytesOverride,
    Duration readTimeout = const Duration(seconds: 90),
  }) : _picker = picker ?? ImagePicker(),
       _openFileOverride = openFileOverride,
       _readBytesOverride = readBytesOverride,
       _readTimeout = readTimeout;

  final ImagePicker _picker;
  final Future<XFile?> Function()? _openFileOverride;
  final Future<Uint8List> Function(XFile file)? _readBytesOverride;
  final Duration _readTimeout;

  static const XTypeGroup _webImageTypes = XTypeGroup(
    label: 'PNG or JPEG images',
    extensions: <String>['png', 'jpg', 'jpeg'],
    mimeTypes: <String>['image/png', 'image/jpeg'],
  );

  Future<Result<ProfileImageSource?>> pick({
    void Function(VerificationEvidencePickPhase phase)? onPhaseChanged,
  }) async {
    try {
      onPhaseChanged?.call(VerificationEvidencePickPhase.choosingFile);
      final XFile? file = _openFileOverride != null
          ? await _openFileOverride!()
          : kIsWeb
          ? await _openFile()
          : await _pickImageOnMobile();
      if (file == null) {
        return const Success<ProfileImageSource?>(null);
      }

      onPhaseChanged?.call(VerificationEvidencePickPhase.readingFile);
      final Uint8List bytes;
      try {
        bytes = await _readBytes(file).timeout(_readTimeout);
      } on TimeoutException catch (error) {
        return FailureResult<ProfileImageSource?>(
          Failure(
            message:
                'Reading the selected file timed out after ${_readTimeout.inSeconds} seconds. '
                'Try a smaller image or check your connection, then tap Upload evidence again.',
            code: 'profile/verification-read-timeout',
            debugMessage: error.toString(),
            cause: error,
          ),
        );
      } catch (error) {
        return FailureResult<ProfileImageSource?>(
          Failure(
            message: _readFailureMessage(error),
            code: 'profile/verification-read-failed',
            debugMessage: error.toString(),
            cause: error,
          ),
        );
      }

      final _PickedFile picked = _PickedFile(
        bytes: bytes,
        filename: file.name,
        declaredContentType: file.mimeType,
      );

      StagingDiagnostics.log(
        'VERIFICATION_EVIDENCE_PICK',
        <String, Object?>{
          'filename': picked.filename,
          'bytes': picked.bytes.lengthInBytes,
          'declaredContentType': picked.declaredContentType,
        },
      );

      onPhaseChanged?.call(VerificationEvidencePickPhase.validating);
      final Failure? failure = VerificationEvidenceValidator.validateBytes(
        bytes: picked.bytes,
        filename: picked.filename,
        declaredContentType: picked.declaredContentType,
      );
      if (failure != null) {
        return FailureResult<ProfileImageSource?>(failure);
      }
      final String contentType =
          VerificationEvidenceValidator.resolveContentType(
            bytes: picked.bytes,
            declaredContentType: picked.declaredContentType,
            filename: picked.filename,
          );
      return Success<ProfileImageSource?>(
        ProfileImageSource(
          bytes: picked.bytes,
          filename: picked.filename.isEmpty ? 'evidence.png' : picked.filename,
          contentType: contentType,
        ),
      );
    } catch (error) {
      return FailureResult<ProfileImageSource?>(
        Failure(
          message: 'The evidence picker could not be opened.',
          code: 'profile/verification-picker',
          debugMessage: error.toString(),
          cause: error,
        ),
      );
    }
  }

  Future<XFile?> _openFile() async {
    if (_openFileOverride != null) {
      return _openFileOverride!();
    }
    return openFile(acceptedTypeGroups: <XTypeGroup>[_webImageTypes]);
  }

  Future<XFile?> _pickImageOnMobile() async {
    return _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: true,
    );
  }

  Future<Uint8List> _readBytes(XFile file) async {
    if (_readBytesOverride != null) {
      return _readBytesOverride!(file);
    }
    return file.readAsBytes();
  }

  static String _readFailureMessage(Object error) {
    final String details = error.toString().toLowerCase();
    if (details.contains('notfound') ||
        details.contains('not found') ||
        details.contains('enoent')) {
      return 'The selected file is unavailable. If it lives in cloud storage, '
          'download it to this device first, then try again.';
    }
    if (details.contains('notreadable') ||
        details.contains('not readable') ||
        details.contains('permission') ||
        details.contains('denied')) {
      return 'The browser could not read the selected file. Check file permissions '
          'or download it locally, then try again.';
    }
    if (details.contains('abort') || details.contains('cancel')) {
      return 'File reading was canceled before it finished.';
    }
    return 'The selected file could not be read. Choose a PNG or JPEG saved on this device.';
  }
}

class _PickedFile {
  const _PickedFile({
    required this.bytes,
    required this.filename,
    this.declaredContentType,
  });

  final Uint8List bytes;
  final String filename;
  final String? declaredContentType;
}
