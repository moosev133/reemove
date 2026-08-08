import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:reemove/core/domain/entities/entity_audit.dart';
import 'package:reemove/core/domain/value_objects/content_policy.dart';
import 'package:reemove/core/errors/failure.dart';
import 'package:reemove/core/firebase/firebase_bootstrap.dart';
import 'package:reemove/core/providers/core_providers.dart';
import 'package:reemove/core/result/result.dart';
import 'package:reemove/features/authentication/application/authentication_providers.dart';
import 'package:reemove/features/authentication/domain/entities/auth_user.dart';
import 'package:reemove/features/profile/application/profile_providers.dart';
import 'package:reemove/features/profile/data/services/platform_verification_evidence_picker.dart';
import 'package:reemove/features/profile/domain/entities/profile_image.dart';
import 'package:reemove/features/profile/domain/entities/profile_privacy_settings.dart';
import 'package:reemove/features/profile/domain/entities/user_profile.dart';
import 'package:reemove/features/profile/domain/entities/verification_request.dart';
import 'package:reemove/features/profile/domain/repositories/verification_evidence_repository.dart';
import 'package:reemove/features/profile/domain/repositories/verification_repository.dart';
import 'package:reemove/features/profile/presentation/screens/profile_verification_screen.dart';

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

class _FakeVerificationRepository implements VerificationRepository {
  VerificationRequest? current;
  int submitCount = 0;
  int draftCount = 0;
  bool failNextDraft = false;
  final StreamController<Result<VerificationRequest?>> _controller =
      StreamController<Result<VerificationRequest?>>.broadcast();

  void emit(VerificationRequest? value) {
    current = value;
    _controller.add(Success<VerificationRequest?>(value));
  }

  @override
  Stream<Result<VerificationRequest?>> watchCurrent() async* {
    yield Success<VerificationRequest?>(current);
    yield* _controller.stream;
  }

  @override
  Future<Result<VerificationRequest>> saveDraft(
    VerificationSubmission submission,
  ) async {
    draftCount += 1;
    if (failNextDraft) {
      failNextDraft = false;
      return const FailureResult<VerificationRequest>(
        Failure(
          message: 'Draft save failed due to network timeout.',
          code: 'functions/deadline-exceeded',
        ),
      );
    }
    current = VerificationRequest(
      id: 'uid',
      uid: 'uid',
      requestedType: submission.requestedType,
      status: VerificationRequestStatus.draft,
      legalName: submission.legalName,
      summary: submission.summary,
      evidence: submission.evidence,
    );
    emit(current);
    return Success<VerificationRequest>(current!);
  }

  @override
  Future<Result<VerificationRequest>> submit(
    VerificationSubmission submission,
  ) async {
    submitCount += 1;
    // Simulate latency so a second tap can race the in-flight submit.
    await Future<void>.delayed(const Duration(milliseconds: 40));
    current = VerificationRequest(
      id: 'uid',
      uid: 'uid',
      requestedType: submission.requestedType,
      status: VerificationRequestStatus.pending,
      legalName: submission.legalName,
      summary: submission.summary,
      evidence: submission.evidence,
      submittedAt: DateTime.utc(2026, 8, 5),
    );
    emit(current);
    return Success<VerificationRequest>(current!);
  }

  @override
  Future<Result<void>> cancel(String requestId) async =>
      const Success<void>(null);
}

class _FakeEvidenceRepository implements VerificationEvidenceRepository {
  int uploadCount = 0;
  bool failNext = false;

  @override
  Future<Result<VerificationEvidence>> upload({
    required String uid,
    required String label,
    required ProfileImageSource source,
    VerificationDocumentKind documentKind = VerificationDocumentKind.other,
    String? issuer,
    DateTime? issuedAt,
    DateTime? expiresAt,
    void Function(double progress)? onProgress,
    void Function(VerificationUploadProgress progress)? onDetailedProgress,
    void Function(Future<bool> Function() cancel)? onRegisterCancel,
  }) async {
    uploadCount += 1;
    onProgress?.call(0.45);
    onDetailedProgress?.call(
      VerificationUploadProgress(
        bytesTransferred: source.bytes.lengthInBytes ~/ 2,
        totalBytes: source.bytes.lengthInBytes,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    onProgress?.call(1);
    onDetailedProgress?.call(
      VerificationUploadProgress(
        bytesTransferred: source.bytes.lengthInBytes,
        totalBytes: source.bytes.lengthInBytes,
      ),
    );
    if (failNext) {
      failNext = false;
      return const FailureResult<VerificationEvidence>(
        Failure(
          message:
              'Network error while uploading evidence. Check connectivity and tap Retry.',
          code: 'storage/retry-limit-exceeded',
        ),
      );
    }
    return Success<VerificationEvidence>(
      VerificationEvidence(
        storagePath: 'verification/$uid/$uid/${source.filename}',
        label: label,
        documentKind: documentKind,
        contentType: source.contentType,
        sizeBytes: source.bytes.lengthInBytes,
        issuer: issuer,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
      ),
    );
  }

  @override
  Future<Result<void>> delete({
    required String uid,
    required String storagePath,
  }) async =>
      const Success<void>(null);
}

class _StallingEvidenceRepository extends _FakeEvidenceRepository {
  @override
  Future<Result<VerificationEvidence>> upload({
    required String uid,
    required String label,
    required ProfileImageSource source,
    VerificationDocumentKind documentKind = VerificationDocumentKind.other,
    String? issuer,
    DateTime? issuedAt,
    DateTime? expiresAt,
    void Function(double progress)? onProgress,
    void Function(VerificationUploadProgress progress)? onDetailedProgress,
    void Function(Future<bool> Function() cancel)? onRegisterCancel,
  }) async {
    onRegisterCancel?.call(() async => true);
    onProgress?.call(0.1);
    onDetailedProgress?.call(
      VerificationUploadProgress(
        bytesTransferred: source.bytes.lengthInBytes ~/ 10,
        totalBytes: source.bytes.lengthInBytes,
      ),
    );
    final Completer<Result<VerificationEvidence>> never =
        Completer<Result<VerificationEvidence>>();
    return never.future;
  }
}

class _StallThenSuccessEvidenceRepository extends _FakeEvidenceRepository {
  bool first = true;

  @override
  Future<Result<VerificationEvidence>> upload({
    required String uid,
    required String label,
    required ProfileImageSource source,
    VerificationDocumentKind documentKind = VerificationDocumentKind.other,
    String? issuer,
    DateTime? issuedAt,
    DateTime? expiresAt,
    void Function(double progress)? onProgress,
    void Function(VerificationUploadProgress progress)? onDetailedProgress,
    void Function(Future<bool> Function() cancel)? onRegisterCancel,
  }) async {
    if (first) {
      first = false;
      final Completer<Result<VerificationEvidence>> never =
          Completer<Result<VerificationEvidence>>();
      return never.future;
    }
    return super.upload(
      uid: uid,
      label: label,
      source: source,
      documentKind: documentKind,
      issuer: issuer,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      onProgress: onProgress,
      onDetailedProgress: onDetailedProgress,
      onRegisterCancel: onRegisterCancel,
    );
  }
}

class _FakePicker extends PlatformVerificationEvidencePicker {
  _FakePicker(this.next, {this.onPick});

  Result<ProfileImageSource?> next;
  final Future<void> Function(
    void Function(VerificationEvidencePickPhase phase)? onPhaseChanged,
  )? onPick;

  @override
  Future<Result<ProfileImageSource?>> pick({
    void Function(VerificationEvidencePickPhase phase)? onPhaseChanged,
  }) async {
    if (onPick != null) {
      await onPick!(onPhaseChanged);
    } else {
      onPhaseChanged?.call(VerificationEvidencePickPhase.choosingFile);
      await Future<void>.delayed(const Duration(milliseconds: 1));
      onPhaseChanged?.call(VerificationEvidencePickPhase.readingFile);
      await Future<void>.delayed(const Duration(milliseconds: 1));
      onPhaseChanged?.call(VerificationEvidencePickPhase.validating);
    }
    return next;
  }
}

UserProfile _profile() {
  final DateTime now = DateTime.utc(2026, 1, 1);
  return UserProfile(
    uid: 'uid',
    username: 'trainer.user',
    usernameNormalized: 'trainer.user',
    displayName: 'Trainer User',
    bio: '',
    role: UserRole.athlete,
    isVerified: false,
    verificationType: VerificationType.none,
    favoriteSportIds: const <String>[],
    sportLevels: const <String, SportLevel>{},
    goals: const <String>[],
    discoveryRadiusKm: 25,
    visibility: Visibility.public,
    followApprovalPolicy: FollowApprovalPolicy.automatic,
    followersCount: 0,
    followingCount: 0,
    postsCount: 0,
    reelsCount: 0,
    onboardingCompleted: true,
    moderationState: ModerationState.active,
    audit: EntityAudit(createdAt: now, updatedAt: now, schemaVersion: 1),
  );
}

AuthUser _authUser() => const AuthUser(
  uid: 'uid',
  email: 'trainer@example.com',
  emailVerified: true,
  isAnonymous: false,
  providers: <AuthProviderType>{AuthProviderType.password},
);

List<Override> _overrides({
  required _FakeVerificationRepository fake,
  _FakeEvidenceRepository? evidence,
  _FakePicker? picker,
}) {
  return <Override>[
    firebaseBootstrapReportProvider.overrideWithValue(
      const FirebaseBootstrapReport(
        status: FirebaseBootstrapStatus.ready,
        appCheckEnabled: false,
        emulatorsEnabled: true,
      ),
    ),
    verificationRepositoryProvider.overrideWithValue(fake),
    currentUserProfileProvider.overrideWith(
      (Ref ref) => Stream<UserProfile?>.value(_profile()),
    ),
    currentAuthUserProvider.overrideWith(
      (Ref ref) async* {
        yield _authUser();
      },
    ),
    if (evidence != null)
      verificationEvidenceRepositoryProvider.overrideWithValue(evidence),
    if (picker != null)
      verificationEvidencePickerProvider.overrideWithValue(picker),
  ];
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required List<Override> overrides,
  Duration uploadTimeout = const Duration(seconds: 90),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: ProfileVerificationScreen(uploadTimeout: uploadTimeout),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _completeEvidenceLabel(WidgetTester tester) async {
  expect(find.text('Describe this evidence'), findsOneWidget);
  // Keep the dialog's default filename label; avoid typing into the wrong field.
  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await tester.pump(); // close dialog + start selecting/upload without finishing delay
}

void main() {
  testWidgets('submit stays disabled until evidence is uploaded', (
    WidgetTester tester,
  ) async {
    final _FakeVerificationRepository fake = _FakeVerificationRepository();
    await _pumpScreen(tester, overrides: _overrides(fake: fake));

    final Finder submit = find.widgetWithText(
      FilledButton,
      'Submit verification request',
    );
    expect(submit, findsOneWidget);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(find.textContaining('Submit stays disabled'), findsOneWidget);
    expect(find.text('Upload evidence'), findsOneWidget);
    expect(find.text('Save draft'), findsOneWidget);
  });

  testWidgets('draft evidence restores as Uploaded rows and enables submit', (
    WidgetTester tester,
  ) async {
    final _FakeVerificationRepository fake = _FakeVerificationRepository()
      ..current = const VerificationRequest(
        id: 'uid',
        uid: 'uid',
        requestedType: VerificationType.trainer,
        status: VerificationRequestStatus.draft,
        legalName: 'Casey Coach',
        summary: 'Competitive coach applying for trainer verification badge.',
        evidence: <VerificationEvidence>[
          VerificationEvidence(
            storagePath: 'verification/uid/uid/a.png',
            label: 'Coaching certificate',
            documentKind: VerificationDocumentKind.certification,
            contentType: 'image/png',
            sizeBytes: 1200,
          ),
        ],
      );

    await _pumpScreen(tester, overrides: _overrides(fake: fake));

    expect(find.text('Coaching certificate'), findsOneWidget);
    expect(find.textContaining('Status: Uploaded'), findsOneWidget);
    final Finder submit = find.widgetWithText(
      FilledButton,
      'Submit verification request',
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });

  testWidgets('PNG upload shows progress then Uploaded and persists draft', (
    WidgetTester tester,
  ) async {
    final _FakeVerificationRepository fake = _FakeVerificationRepository();
    final _FakeEvidenceRepository evidence = _FakeEvidenceRepository();
    final _FakePicker picker = _FakePicker(
      Success<ProfileImageSource?>(
        ProfileImageSource(
          bytes: _pngBytes(),
          filename: 'cert.png',
          contentType: 'image/png',
        ),
      ),
    );

    await _pumpScreen(
      tester,
      overrides: _overrides(fake: fake, evidence: evidence, picker: picker),
    );

    await _tapVisible(tester, find.text('Upload evidence'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2));
    expect(
      find.textContaining(
        RegExp(r'Status: (Choosing file|Reading file|Validating|Selected)'),
      ),
      findsOneWidget,
    );
    await _completeEvidenceLabel(tester);
    expect(
      find.textContaining(RegExp(r'Status: (Selecting|Uploading file|Saving evidence)')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.textContaining('Status: Uploaded'), findsOneWidget);
    expect(evidence.uploadCount, 1);
    expect(fake.draftCount, greaterThanOrEqualTo(1));
    expect(fake.current?.evidence, isNotEmpty);

    final Finder submit = find.widgetWithText(
      FilledButton,
      'Submit verification request',
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });

  testWidgets('upload failure shows actionable error and keeps submit disabled', (
    WidgetTester tester,
  ) async {
    final _FakeVerificationRepository fake = _FakeVerificationRepository();
    final _FakeEvidenceRepository evidence = _FakeEvidenceRepository()
      ..failNext = true;
    final _FakePicker picker = _FakePicker(
      Success<ProfileImageSource?>(
        ProfileImageSource(
          bytes: _pngBytes(),
          filename: 'cert.png',
          contentType: 'image/png',
        ),
      ),
    );

    await _pumpScreen(
      tester,
      overrides: _overrides(fake: fake, evidence: evidence, picker: picker),
    );

    await _tapVisible(tester, find.text('Upload evidence'));
    await tester.pumpAndSettle();
    await _completeEvidenceLabel(tester);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(evidence.uploadCount, 1);
    expect(find.textContaining('Status: Failed'), findsOneWidget);
    expect(find.textContaining('Network error'), findsWidgets);
    expect(find.text('Retry'), findsOneWidget);
    final Finder submit = find.widgetWithText(
      FilledButton,
      'Submit verification request',
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
  });

  testWidgets('retry succeeds without duplicate evidence rows', (
    WidgetTester tester,
  ) async {
    final _FakeVerificationRepository fake = _FakeVerificationRepository();
    final _FakeEvidenceRepository evidence = _FakeEvidenceRepository()
      ..failNext = true;
    final _FakePicker picker = _FakePicker(
      Success<ProfileImageSource?>(
        ProfileImageSource(
          bytes: _pngBytes(),
          filename: 'cert.png',
          contentType: 'image/png',
        ),
      ),
    );

    await _pumpScreen(
      tester,
      overrides: _overrides(fake: fake, evidence: evidence, picker: picker),
    );

    await _tapVisible(tester, find.text('Upload evidence'));
    await tester.pumpAndSettle();
    await _completeEvidenceLabel(tester);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(evidence.uploadCount, 1);
    expect(find.textContaining('Status: Failed'), findsOneWidget);

    await _tapVisible(tester, find.text('Retry'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.textContaining('Status: Uploaded'), findsOneWidget);
    expect(find.textContaining('Status: Failed'), findsNothing);
    expect(evidence.uploadCount, 2);
    expect(find.widgetWithText(ListTile, 'cert.png'), findsOneWidget);
  });

  testWidgets('widget rebuild does not erase restored evidence', (
    WidgetTester tester,
  ) async {
    final _FakeVerificationRepository fake = _FakeVerificationRepository()
      ..current = const VerificationRequest(
        id: 'uid',
        uid: 'uid',
        requestedType: VerificationType.trainer,
        status: VerificationRequestStatus.draft,
        legalName: 'Casey Coach',
        summary: 'Competitive coach applying for trainer verification badge.',
        evidence: <VerificationEvidence>[
          VerificationEvidence(
            storagePath: 'verification/uid/uid/a.png',
            label: 'Coaching certificate',
            documentKind: VerificationDocumentKind.certification,
            contentType: 'image/png',
            sizeBytes: 1200,
          ),
        ],
      );

    await _pumpScreen(tester, overrides: _overrides(fake: fake));
    expect(find.text('Coaching certificate'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(fake: fake),
        child: const MaterialApp(home: ProfileVerificationScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Coaching certificate'), findsOneWidget);
    expect(find.textContaining('Status: Uploaded'), findsOneWidget);
  });

  testWidgets('double submit only calls submit once', (
    WidgetTester tester,
  ) async {
    final _FakeVerificationRepository fake = _FakeVerificationRepository()
      ..current = const VerificationRequest(
        id: 'uid',
        uid: 'uid',
        requestedType: VerificationType.trainer,
        status: VerificationRequestStatus.draft,
        legalName: 'Casey Coach',
        summary: 'Competitive coach applying for trainer verification badge.',
        evidence: <VerificationEvidence>[
          VerificationEvidence(
            storagePath: 'verification/uid/uid/a.png',
            label: 'Coaching certificate',
            documentKind: VerificationDocumentKind.certification,
            contentType: 'image/png',
            sizeBytes: 1200,
          ),
        ],
      );

    await _pumpScreen(tester, overrides: _overrides(fake: fake));

    final Finder submit = find.widgetWithText(
      FilledButton,
      'Submit verification request',
    );
    await _tapVisible(tester, submit);
    await tester.pump(); // _submitting = true
    await tester.tap(submit, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(fake.submitCount, 1);
  });

  testWidgets('stalled upload times out and exposes Retry', (
    WidgetTester tester,
  ) async {
    final _FakeVerificationRepository fake = _FakeVerificationRepository();
    final _StallingEvidenceRepository evidence = _StallingEvidenceRepository();
    final _FakePicker picker = _FakePicker(
      Success<ProfileImageSource?>(
        ProfileImageSource(
          bytes: _pngBytes(),
          filename: 'stall.png',
          contentType: 'image/png',
        ),
      ),
    );

    await _pumpScreen(
      tester,
      overrides: _overrides(fake: fake, evidence: evidence, picker: picker),
      uploadTimeout: const Duration(milliseconds: 80),
    );

    await _tapVisible(tester, find.text('Upload evidence'));
    await tester.pumpAndSettle();
    await _completeEvidenceLabel(tester);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    expect(find.textContaining('Status: Failed'), findsOneWidget);
    expect(find.textContaining('Upload timed out'), findsWidgets);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('storage success but draft-save failure keeps row failed', (
    WidgetTester tester,
  ) async {
    final _FakeVerificationRepository fake = _FakeVerificationRepository()
      ..failNextDraft = true;
    final _FakeEvidenceRepository evidence = _FakeEvidenceRepository();
    final _FakePicker picker = _FakePicker(
      Success<ProfileImageSource?>(
        ProfileImageSource(
          bytes: _pngBytes(),
          filename: 'draft-fail.png',
          contentType: 'image/png',
        ),
      ),
    );

    await _pumpScreen(
      tester,
      overrides: _overrides(fake: fake, evidence: evidence, picker: picker),
    );

    await _tapVisible(tester, find.text('Upload evidence'));
    await tester.pumpAndSettle();
    await _completeEvidenceLabel(tester);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.textContaining('Status: Failed'), findsOneWidget);
    expect(
      find.textContaining('Storage upload finished, but draft save failed'),
      findsOneWidget,
    );
    final Finder submit = find.widgetWithText(
      FilledButton,
      'Submit verification request',
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
  });

  testWidgets('timeout can retry and reach Uploaded', (WidgetTester tester) async {
    final _FakeVerificationRepository fake = _FakeVerificationRepository();
    final _StallThenSuccessEvidenceRepository evidence =
        _StallThenSuccessEvidenceRepository();
    final _FakePicker picker = _FakePicker(
      Success<ProfileImageSource?>(
        ProfileImageSource(
          bytes: _pngBytes(),
          filename: 'retry-after-timeout.png',
          contentType: 'image/png',
        ),
      ),
    );

    await _pumpScreen(
      tester,
      overrides: _overrides(fake: fake, evidence: evidence, picker: picker),
      uploadTimeout: const Duration(milliseconds: 80),
    );

    await _tapVisible(tester, find.text('Upload evidence'));
    await tester.pumpAndSettle();
    await _completeEvidenceLabel(tester);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(find.textContaining('Status: Failed'), findsOneWidget);

    await _tapVisible(tester, find.text('Retry'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
    expect(find.textContaining('Status: Uploaded'), findsOneWidget);
  });

  testWidgets('in-flight upload can be canceled', (WidgetTester tester) async {
    final _FakeVerificationRepository fake = _FakeVerificationRepository();
    final _StallingEvidenceRepository evidence = _StallingEvidenceRepository();
    final _FakePicker picker = _FakePicker(
      Success<ProfileImageSource?>(
        ProfileImageSource(
          bytes: _pngBytes(),
          filename: 'cancel.png',
          contentType: 'image/png',
        ),
      ),
    );

    await _pumpScreen(
      tester,
      overrides: _overrides(fake: fake, evidence: evidence, picker: picker),
      uploadTimeout: const Duration(milliseconds: 500),
    );

    await _tapVisible(tester, find.text('Upload evidence'));
    await tester.pump(const Duration(milliseconds: 5));
    await tester.pumpAndSettle();
    await _completeEvidenceLabel(tester);
    await tester.pump();
    expect(find.byKey(const Key('evidence-cancel-upload')), findsOneWidget);
    await tester.tap(find.byKey(const Key('evidence-cancel-upload')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pumpAndSettle();
    expect(find.textContaining('Status: Failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('unsupported PDF pick shows immediate clear error', (
    WidgetTester tester,
  ) async {
    final _FakeVerificationRepository fake = _FakeVerificationRepository();
    final _FakePicker picker = _FakePicker(
      const FailureResult<ProfileImageSource?>(
        Failure(
          message:
              'PDF documents are not supported yet. Upload a PNG or JPEG image of your certificate.',
          code: 'profile/verification-pdf-unsupported',
        ),
      ),
      onPick: (void Function(VerificationEvidencePickPhase phase)? onPhaseChanged) async {
        onPhaseChanged?.call(VerificationEvidencePickPhase.choosingFile);
        onPhaseChanged?.call(VerificationEvidencePickPhase.readingFile);
        onPhaseChanged?.call(VerificationEvidencePickPhase.validating);
      },
    );

    await _pumpScreen(
      tester,
      overrides: _overrides(fake: fake, picker: picker),
    );

    await _tapVisible(tester, find.text('Upload evidence'));
    await tester.pump(); // snackbar frame
    expect(find.textContaining('Status: Failed'), findsOneWidget);
    expect(
      find.textContaining('PDF documents are not supported yet'),
      findsWidgets,
    );
    expect(find.textContaining('Status: Uploaded'), findsNothing);
  });

  testWidgets('delayed file selection shows Choosing file without timing out', (
    WidgetTester tester,
  ) async {
    final _FakeVerificationRepository fake = _FakeVerificationRepository();
    final _FakeEvidenceRepository evidence = _FakeEvidenceRepository();
    final _FakePicker picker = _FakePicker(
      Success<ProfileImageSource?>(
        ProfileImageSource(
          bytes: _pngBytes(),
          filename: 'slow-choose.png',
          contentType: 'image/png',
        ),
      ),
      onPick: (void Function(VerificationEvidencePickPhase phase)? onPhaseChanged) async {
        onPhaseChanged?.call(VerificationEvidencePickPhase.choosingFile);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        onPhaseChanged?.call(VerificationEvidencePickPhase.readingFile);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        onPhaseChanged?.call(VerificationEvidencePickPhase.validating);
      },
    );

    await _pumpScreen(
      tester,
      overrides: _overrides(fake: fake, evidence: evidence, picker: picker),
      uploadTimeout: const Duration(milliseconds: 80),
    );

    await _tapVisible(tester, find.text('Upload evidence'));
    await tester.pump();
    expect(find.textContaining('Status: Choosing file'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.textContaining('browser file picker timed out'), findsNothing);
    expect(find.textContaining('Status: Reading file'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 40));
    await _completeEvidenceLabel(tester);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.textContaining('Status: Uploaded'), findsOneWidget);
  });

  testWidgets('slow file reading shows Reading file then Uploaded', (
    WidgetTester tester,
  ) async {
    final _FakeVerificationRepository fake = _FakeVerificationRepository();
    final _FakeEvidenceRepository evidence = _FakeEvidenceRepository();
    final _FakePicker picker = _FakePicker(
      Success<ProfileImageSource?>(
        ProfileImageSource(
          bytes: _pngBytes(),
          filename: 'slow-read.png',
          contentType: 'image/png',
        ),
      ),
      onPick: (void Function(VerificationEvidencePickPhase phase)? onPhaseChanged) async {
        onPhaseChanged?.call(VerificationEvidencePickPhase.choosingFile);
        onPhaseChanged?.call(VerificationEvidencePickPhase.readingFile);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        onPhaseChanged?.call(VerificationEvidencePickPhase.validating);
      },
    );

    await _pumpScreen(
      tester,
      overrides: _overrides(fake: fake, evidence: evidence, picker: picker),
    );

    await _tapVisible(tester, find.text('Upload evidence'));
    await tester.pump();
    expect(find.textContaining('Status: Reading file'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.textContaining('browser file picker timed out'), findsNothing);
    await _completeEvidenceLabel(tester);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.textContaining('Status: Uploaded'), findsOneWidget);
  });

  testWidgets('oversized pick failure shows size message not picker timeout', (
    WidgetTester tester,
  ) async {
    final _FakeVerificationRepository fake = _FakeVerificationRepository();
    final _FakePicker picker = _FakePicker(
      const FailureResult<ProfileImageSource?>(
        Failure(
          message: 'Choose an evidence image smaller than 15 MB.',
          code: 'profile/verification-size',
        ),
      ),
      onPick: (void Function(VerificationEvidencePickPhase phase)? onPhaseChanged) async {
        onPhaseChanged?.call(VerificationEvidencePickPhase.choosingFile);
        onPhaseChanged?.call(VerificationEvidencePickPhase.readingFile);
        onPhaseChanged?.call(VerificationEvidencePickPhase.validating);
      },
    );

    await _pumpScreen(
      tester,
      overrides: _overrides(fake: fake, picker: picker),
    );

    await _tapVisible(tester, find.text('Upload evidence'));
    await tester.pumpAndSettle();

    expect(find.textContaining('smaller than 15 MB'), findsWidgets);
    expect(find.textContaining('browser file picker timed out'), findsNothing);
    expect(find.textContaining('Status: Failed'), findsOneWidget);
  });
}
