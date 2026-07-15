import '../../../../core/result/result.dart';

abstract interface class MessagingDeviceRepository {
  Future<Result<void>> registerCurrentDevice();
  Future<Result<void>> unregisterCurrentDevice();
}
