import 'user_profile.dart';

enum VerificationRequestStatus { draft, pending, approved, rejected, canceled }

class VerificationEvidence {
  const VerificationEvidence({required this.storagePath, required this.label});

  final String storagePath;
  final String label;
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
    required this.submittedAt,
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
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;
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
