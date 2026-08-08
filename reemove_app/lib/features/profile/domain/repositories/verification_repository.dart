import '../../../../core/result/result.dart';
import '../entities/verification_request.dart';

abstract interface class VerificationRepository {
  Stream<Result<VerificationRequest?>> watchCurrent();
  Future<Result<VerificationRequest>> saveDraft(VerificationSubmission submission);
  Future<Result<VerificationRequest>> submit(VerificationSubmission submission);
  Future<Result<void>> cancel(String requestId);
}
