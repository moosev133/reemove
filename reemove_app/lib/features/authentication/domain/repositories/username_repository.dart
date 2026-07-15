import '../../../../core/result/result.dart';
import '../entities/username_availability.dart';

abstract interface class UsernameRepository {
  Future<Result<UsernameAvailability>> checkAvailability(String username);
}
