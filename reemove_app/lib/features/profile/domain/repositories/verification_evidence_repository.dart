import '../../../../core/result/result.dart';
import '../entities/profile_image.dart';
import '../entities/verification_request.dart';

abstract interface class VerificationEvidenceRepository {
  Future<Result<VerificationEvidence>> upload({
    required String uid,
    required String label,
    required ProfileImageSource source,
  });

  Future<Result<void>> delete({
    required String uid,
    required String storagePath,
  });
}
