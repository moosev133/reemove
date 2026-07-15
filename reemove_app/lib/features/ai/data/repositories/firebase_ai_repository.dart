import '../../domain/entities/ai_models.dart';
import '../../domain/repositories/ai_repository.dart';
import '../datasources/firebase_ai_remote_data_source.dart';

class FirebaseAiRepository implements AiRepository {
  FirebaseAiRepository(this._remote);

  final FirebaseAiRemoteDataSource _remote;

  Future<AiGeneratedResult> _call(
    AiModule module,
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    final json = await _remote.call(functionName, payload);
    return AiGeneratedResult.fromJson(module, json);
  }

  @override
  Future<AiGeneratedResult> askCoach({
    required String message,
    String? conversationId,
  }) => _call(AiModule.coach, 'aiCoach', {
    'message': message.trim(),
    'conversationId': ?conversationId,
  });

  @override
  Future<AiGeneratedResult> generateWorkout({
    required String sport,
    required String goal,
    required String level,
    required int daysPerWeek,
    required int sessionMinutes,
    String? availableEquipment,
    String? limitations,
  }) => _call(AiModule.workout, 'generateWorkoutPlan', {
    'sport': sport.trim(),
    'goal': goal.trim(),
    'level': level.trim(),
    'daysPerWeek': daysPerWeek,
    'sessionMinutes': sessionMinutes,
    if (availableEquipment?.trim().isNotEmpty == true)
      'availableEquipment': availableEquipment!.trim(),
    if (limitations?.trim().isNotEmpty == true)
      'limitations': limitations!.trim(),
  });

  @override
  Future<AiGeneratedResult> generateNutritionGuidance({
    required String sport,
    required String goal,
    required String activityLevel,
    String? dietaryPreferences,
    String? allergies,
  }) => _call(AiModule.nutrition, 'generateNutritionGuidance', {
    'sport': sport.trim(),
    'goal': goal.trim(),
    'activityLevel': activityLevel.trim(),
    if (dietaryPreferences?.trim().isNotEmpty == true)
      'dietaryPreferences': dietaryPreferences!.trim(),
    if (allergies?.trim().isNotEmpty == true) 'allergies': allergies!.trim(),
  });

  @override
  Future<AiGeneratedResult> rankMatches({
    required String sport,
    required List<String> candidateIds,
    String? preferences,
  }) => _call(AiModule.matchmaker, 'rankPlayerMatches', {
    'sport': sport.trim(),
    'candidateIds': candidateIds,
    if (preferences?.trim().isNotEmpty == true)
      'preferences': preferences!.trim(),
  });

  @override
  Future<AiGeneratedResult> generateChallenge({
    required String sport,
    required String level,
    required int durationDays,
    String? equipment,
  }) => _call(AiModule.challenge, 'generateSafeChallenge', {
    'sport': sport.trim(),
    'level': level.trim(),
    'durationDays': durationDays,
    if (equipment?.trim().isNotEmpty == true) 'equipment': equipment!.trim(),
  });

  @override
  Future<AiGeneratedResult> createContent({
    required String sourceText,
    required String tone,
    required String platform,
  }) => _call(AiModule.content, 'createSportsContent', {
    'sourceText': sourceText.trim(),
    'tone': tone.trim(),
    'platform': platform.trim(),
  });

  @override
  Future<AiGeneratedResult> getTrainerInsights({required String period}) =>
      _call(AiModule.trainerInsights, 'getTrainerBusinessInsights', {
        'period': period,
      });
}
