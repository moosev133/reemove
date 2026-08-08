import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/errors/failure.dart';
import 'package:reemove/features/profile/domain/entities/profile_image.dart';
import 'package:reemove/features/profile/domain/services/verification_evidence_validator.dart';

Uint8List _pngBytes() => Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
]);

Uint8List _jpegBytes() =>
    Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);

Uint8List _pdfBytes() =>
    Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]);

void main() {
  test('valid PNG passes client validation', () {
    final Failure? failure = VerificationEvidenceValidator.validateBytes(
      bytes: _pngBytes(),
      filename: 'cert.png',
      declaredContentType: 'image/png',
    );
    expect(failure, isNull);
  });

  test('valid JPEG passes client validation', () {
    final Failure? failure = VerificationEvidenceValidator.validateBytes(
      bytes: _jpegBytes(),
      filename: 'cert.jpg',
      declaredContentType: 'image/jpeg',
    );
    expect(failure, isNull);
  });

  test('octet-stream PNG is accepted via magic bytes', () {
    final Failure? failure = VerificationEvidenceValidator.validateBytes(
      bytes: _pngBytes(),
      filename: 'cert.png',
      declaredContentType: 'application/octet-stream',
    );
    expect(failure, isNull);
    expect(
      VerificationEvidenceValidator.resolveContentType(
        bytes: _pngBytes(),
        declaredContentType: 'application/octet-stream',
        filename: 'cert.png',
      ),
      'image/png',
    );
  });

  test('unsupported PDF shows clear immediate error', () {
    final Failure? failure = VerificationEvidenceValidator.validateBytes(
      bytes: _pdfBytes(),
      filename: 'cert.pdf',
      declaredContentType: 'application/pdf',
    );
    expect(failure, isNotNull);
    expect(failure!.message, contains('PDF'));
  });

  test('renamed non-image with .png extension is rejected', () {
    final Failure? failure = VerificationEvidenceValidator.validateBytes(
      bytes: Uint8List.fromList(<int>[0x00, 0x01, 0x02, 0x03, 0x04]),
      filename: 'fake.png',
      declaredContentType: 'image/png',
    );
    expect(failure, isNotNull);
    expect(failure!.code, 'profile/verification-magic');
  });

  test('oversized image is rejected', () {
    final Uint8List huge = Uint8List(15 * 1024 * 1024 + 1);
    huge.setRange(0, _pngBytes().length, _pngBytes());
    final Failure? failure = VerificationEvidenceValidator.validateSource(
      ProfileImageSource(
        bytes: huge,
        filename: 'huge.png',
        contentType: 'image/png',
      ),
    );
    expect(failure, isNotNull);
    expect(failure!.code, 'profile/verification-size');
  });
}
