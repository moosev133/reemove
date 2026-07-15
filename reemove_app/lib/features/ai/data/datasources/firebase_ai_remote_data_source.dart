import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/ai_models.dart';

class FirebaseAiRemoteDataSource {
  FirebaseAiRemoteDataSource(this._functions);

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> call(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    try {
      final callable = _functions.httpsCallable(
        functionName,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 75)),
      );
      final response = await callable.call<Map<String, dynamic>>(payload);
      return Map<String, dynamic>.from(response.data);
    } on FirebaseFunctionsException catch (error) {
      throw AiRequestException(
        error.code,
        error.message ?? 'The AI request could not be completed.',
      );
    } catch (_) {
      throw const AiRequestException(
        'unknown',
        'The AI request could not be completed.',
      );
    }
  }
}
