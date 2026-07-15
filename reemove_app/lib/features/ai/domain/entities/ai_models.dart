enum AiModule {
  coach,
  workout,
  nutrition,
  matchmaker,
  challenge,
  content,
  trainerInsights,
}

extension AiModuleWireName on AiModule {
  String get wireName => switch (this) {
    AiModule.coach => 'coach',
    AiModule.workout => 'workout',
    AiModule.nutrition => 'nutrition',
    AiModule.matchmaker => 'matchmaker',
    AiModule.challenge => 'challenge',
    AiModule.content => 'content',
    AiModule.trainerInsights => 'trainer_insights',
  };
}

class AiGeneratedResult {
  const AiGeneratedResult({
    required this.module,
    required this.outputId,
    required this.data,
    required this.createdAt,
  });

  factory AiGeneratedResult.fromJson(
    AiModule module,
    Map<String, dynamic> json,
  ) {
    final Object? rawData = json['result'];
    return AiGeneratedResult(
      module: module,
      outputId: json['outputId'] as String? ?? '',
      data: rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{},
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  final AiModule module;
  final String outputId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
}

class AiRequestException implements Exception {
  const AiRequestException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AiRequestException($code): $message';
}
