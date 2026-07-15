import '../../../../core/result/result.dart';
import '../entities/onboarding_draft.dart';
import '../entities/onboarding_policy.dart';

abstract interface class OnboardingRepository {
  Future<Result<OnboardingDraft?>> loadDraft(String uid);
  Future<Result<OnboardingPolicy>> loadPolicy();
  Future<Result<OnboardingDraft>> saveProgress(OnboardingDraft draft);
  Future<Result<void>> complete(OnboardingDraft draft);
}
