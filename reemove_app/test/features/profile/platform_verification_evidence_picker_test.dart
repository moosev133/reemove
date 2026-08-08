import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/result/result.dart';
import 'package:reemove/features/profile/data/services/platform_verification_evidence_picker.dart';
import 'package:reemove/features/profile/domain/entities/profile_image.dart';

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

void main() {
  test('delayed openFile does not time out while choosing', () async {
    final PlatformVerificationEvidencePicker picker =
        PlatformVerificationEvidencePicker(
          openFileOverride: () async {
            await Future<void>.delayed(const Duration(milliseconds: 120));
            return XFile.fromData(
              _pngBytes(),
              name: 'delayed.png',
              mimeType: 'image/png',
            );
          },
          readBytesOverride: (XFile file) => file.readAsBytes(),
          readTimeout: const Duration(milliseconds: 50),
        );

    final List<VerificationEvidencePickPhase> phases =
        <VerificationEvidencePickPhase>[];
    final Result<ProfileImageSource?> result = await picker.pick(
      onPhaseChanged: phases.add,
    );

    expect(phases.first, VerificationEvidencePickPhase.choosingFile);
    expect(result, isA<Success<ProfileImageSource?>>());
    expect(
      result.when<ProfileImageSource?>(
        success: (ProfileImageSource? value) => value,
        failure: (_) => null,
      ),
      isNotNull,
    );
  });

  test('slow readAsBytes reports Reading file and can still succeed', () async {
    final PlatformVerificationEvidencePicker picker =
        PlatformVerificationEvidencePicker(
          openFileOverride: () async => XFile.fromData(
            _pngBytes(),
            name: 'slow-read.png',
            mimeType: 'image/png',
          ),
          readBytesOverride: (XFile file) async {
            await Future<void>.delayed(const Duration(milliseconds: 80));
            return file.readAsBytes();
          },
          readTimeout: const Duration(seconds: 2),
        );

    final List<VerificationEvidencePickPhase> phases =
        <VerificationEvidencePickPhase>[];
    final Result<ProfileImageSource?> result = await picker.pick(
      onPhaseChanged: phases.add,
    );

    expect(phases, contains(VerificationEvidencePickPhase.readingFile));
    expect(result, isA<Success<ProfileImageSource?>>());
  });

  test('read timeout returns read-timeout message not picker timeout', () async {
    final PlatformVerificationEvidencePicker picker =
        PlatformVerificationEvidencePicker(
          openFileOverride: () async => XFile.fromData(
            _pngBytes(),
            name: 'stall-read.png',
            mimeType: 'image/png',
          ),
          readBytesOverride: (_) => Completer<Uint8List>().future,
          readTimeout: const Duration(milliseconds: 40),
        );

    final Result<ProfileImageSource?> result = await picker.pick();

    expect(result, isA<FailureResult<ProfileImageSource?>>());
    expect(
      result.when<String>(
        success: (_) => '',
        failure: (failure) => failure.message,
      ),
      contains('Reading the selected file timed out'),
    );
    expect(
      result.when<String>(
        success: (_) => '',
        failure: (failure) => failure.message,
      ),
      isNot(contains('browser file picker timed out')),
    );
  });

  test('oversized bytes return exact size message', () async {
    final Uint8List huge = Uint8List(16 * 1024 * 1024);
    huge.setRange(0, 8, _pngBytes());

    final PlatformVerificationEvidencePicker picker =
        PlatformVerificationEvidencePicker(
          openFileOverride: () async => XFile.fromData(
            huge,
            name: 'huge.png',
            mimeType: 'image/png',
          ),
          readBytesOverride: (XFile file) => file.readAsBytes(),
        );

    final Result<ProfileImageSource?> result = await picker.pick();

    expect(result, isA<FailureResult<ProfileImageSource?>>());
    expect(
      result.when<String>(
        success: (_) => '',
        failure: (failure) => failure.message,
      ),
      'Choose an evidence image smaller than 15 MB.',
    );
  });

  test('malformed bytes return magic-byte message', () async {
    final PlatformVerificationEvidencePicker picker =
        PlatformVerificationEvidencePicker(
          openFileOverride: () async => XFile.fromData(
            Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
            name: 'bad.png',
            mimeType: 'image/png',
          ),
          readBytesOverride: (XFile file) => file.readAsBytes(),
        );

    final Result<ProfileImageSource?> result = await picker.pick();

    expect(result, isA<FailureResult<ProfileImageSource?>>());
    expect(
      result.when<String>(
        success: (_) => '',
        failure: (failure) => failure.message,
      ),
      contains('not a valid PNG or JPEG image'),
    );
  });

  test('unavailable read errors surface cloud/local guidance', () async {
    final PlatformVerificationEvidencePicker picker =
        PlatformVerificationEvidencePicker(
          openFileOverride: () async => XFile.fromData(
            _pngBytes(),
            name: 'cloud.png',
            mimeType: 'image/png',
          ),
          readBytesOverride: (_) => throw StateError('NotFoundError: file missing'),
        );

    final Result<ProfileImageSource?> result = await picker.pick();

    expect(result, isA<FailureResult<ProfileImageSource?>>());
    expect(
      result.when<String>(
        success: (_) => '',
        failure: (failure) => failure.message,
      ),
      contains('unavailable'),
    );
  });
}

