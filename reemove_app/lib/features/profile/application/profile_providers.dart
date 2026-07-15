import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/result/result.dart';
import '../domain/entities/user_profile.dart';

final publicProfileByUsernameProvider =
    FutureProvider.family<UserProfile?, String>((
      Ref ref,
      String username,
    ) async {
      final Result<UserProfile?> result = await ref
          .watch(userProfileRepositoryProvider)
          .getByUsername(username);
      return result.when<UserProfile?>(
        success: (UserProfile? profile) => profile,
        failure: (failure) => throw StateError(failure.message),
      );
    });
