import 'user_profile.dart';

enum VerificationRequestStatus { draft, pending, approved, rejected, canceled }

enum VerificationDocumentKind {
  identity,
  certification,
  registration,
  other,
}

class VerificationEvidence {
  const VerificationEvidence({
    required this.storagePath,
    required this.label,
    this.documentKind = VerificationDocumentKind.other,
    this.contentType,
    this.sizeBytes,
    this.issuer,
    this.issuedAt,
    this.expiresAt,
  });

  final String storagePath;
  final String label;
  final VerificationDocumentKind documentKind;
  final String? contentType;
  final int? sizeBytes;
  final String? issuer;
  final DateTime? issuedAt;
  final DateTime? expiresAt;

  Map<String, Object?> toCallableJson() => <String, Object?>{
    'storagePath': storagePath,
    'label': label,
    'documentKind': documentKind.name,
    if (contentType != null) 'contentType': contentType,
    if (sizeBytes != null) 'sizeBytes': sizeBytes,
    if (issuer != null && issuer!.trim().isNotEmpty) 'issuer': issuer,
    if (issuedAt != null) 'issuedAt': issuedAt!.toUtc().toIso8601String(),
    if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
  };
}

class VerificationRequest {
  const VerificationRequest({
    required this.id,
    required this.uid,
    required this.requestedType,
    required this.status,
    required this.legalName,
    required this.summary,
    required this.evidence,
    this.submittedAt,
    this.reviewedAt,
    this.rejectionReason,
  });

  final String id;
  final String uid;
  final VerificationType requestedType;
  final VerificationRequestStatus status;
  final String legalName;
  final String summary;
  final List<VerificationEvidence> evidence;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  bool get isEditableDraft =>
      status == VerificationRequestStatus.draft ||
      status == VerificationRequestStatus.canceled;
}

class VerificationSubmission {
  const VerificationSubmission({
    required this.requestedType,
    required this.legalName,
    required this.summary,
    required this.evidence,
  });

  final VerificationType requestedType;
  final String legalName;
  final String summary;
  final List<VerificationEvidence> evidence;
}
