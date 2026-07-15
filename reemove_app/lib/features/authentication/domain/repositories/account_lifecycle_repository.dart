import '../../../../core/result/result.dart';
import '../entities/account_provisioning_request.dart';

abstract interface class AccountLifecycleRepository {
  Future<Result<AccountProvisioningResult>> provisionAccount(
    AccountProvisioningRequest request,
  );

  Future<Result<void>> syncAuthProviders();

  Future<Result<void>> revokeSessions();

  Future<Result<void>> requestAccountDeletion();
}
