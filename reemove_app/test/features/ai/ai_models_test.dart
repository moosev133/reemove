import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/ai/domain/entities/ai_models.dart';

void main() {
  test('AiGeneratedResult parses callable response', () {
    final result = AiGeneratedResult.fromJson(AiModule.coach, {
      'outputId': 'out-1',
      'createdAt': '2026-07-14T12:00:00.000Z',
      'result': {'answer': 'Use a gradual plan.'},
    });

    expect(result.outputId, 'out-1');
    expect(result.data['answer'], 'Use a gradual plan.');
    expect(result.module, AiModule.coach);
  });
}
