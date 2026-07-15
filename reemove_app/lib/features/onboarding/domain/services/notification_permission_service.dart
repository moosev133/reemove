import '../../../../core/result/result.dart';
import '../entities/onboarding_draft.dart';

abstract interface class NotificationPermissionService {
  Future<Result<NotificationPermissionDecision>> requestPermission();
}
