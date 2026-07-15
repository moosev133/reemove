import '../entities/ai_models.dart';

abstract interface class AiRepository {
  Future<AiGeneratedResult> askCoach({
    required String message,
    String? conversationId,
  });

  Future<AiGeneratedResult> generateWorkout({
    required String sport,
    required String goal,
    required String level,
    required int daysPerWeek,
    required int sessionMinutes,
    String? availableEquipment,
    String? limitations,
  });

  Future<AiGeneratedResult> generateNutritionGuidance({
    required String sport,
    required String goal,
    required String activityLevel,
    String? dietaryPreferences,
    String? allergies,
  });

  Future<AiGeneratedResult> rankMatches({
    required String sport,
    required List<String> candidateIds,
    String? preferences,
  });

  Future<AiGeneratedResult> generateChallenge({
    required String sport,
    required String level,
    required int durationDays,
    String? equipment,
  });

  Future<AiGeneratedResult> createContent({
    required String sourceText,
    required String tone,
    required String platform,
  });

  Future<AiGeneratedResult> getTrainerInsights({required String period});
}
