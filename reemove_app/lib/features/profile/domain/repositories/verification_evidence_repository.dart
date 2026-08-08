import '../../../../core/result/result.dart';
import '../entities/profile_image.dart';
import '../entities/verification_request.dart';

class VerificationUploadProgress {
  const VerificationUploadProgress({
    required this.bytesTransferred,
    required this.totalBytes,
  });

  final int bytesTransferred;
  final int totalBytes;
}

abstract interface class VerificationEvidenceRepository {
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
  });

  Future<Result<void>> delete({
    required String uid,
    required String storagePath,
  });
}
