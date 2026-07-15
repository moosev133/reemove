import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/datasources/firebase_ai_remote_data_source.dart';
import '../data/repositories/firebase_ai_repository.dart';
import '../domain/entities/ai_models.dart';
import '../domain/repositories/ai_repository.dart';

final Provider<AiRepository> aiRepositoryProvider = Provider<AiRepository>((
  Ref ref,
) {
  return FirebaseAiRepository(
    FirebaseAiRemoteDataSource(ref.watch(firebaseFunctionsProvider)),
  );
});

class AiActionController extends AsyncNotifier<AiGeneratedResult?> {
  @override
  Future<AiGeneratedResult?> build() async => null;

  Future<void> execute(
    Future<AiGeneratedResult> Function(AiRepository repository) action,
  ) async {
    state = const AsyncLoading<AiGeneratedResult?>();
    state = await AsyncValue.guard(
      () => action(ref.read(aiRepositoryProvider)),
    );
  }

  void clear() => state = const AsyncData<AiGeneratedResult?>(null);
}

final AsyncNotifierProvider<AiActionController, AiGeneratedResult?>
aiActionControllerProvider =
    AsyncNotifierProvider<AiActionController, AiGeneratedResult?>(
      AiActionController.new,
    );
