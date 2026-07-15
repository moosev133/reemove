import '../../../../../core/domain/entities/entity_audit.dart';

enum SportLeaderboardPeriod { daily, weekly, monthly, season, allTime }

class SportLeaderboardEntry {
  const SportLeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.username,
    required this.rank,
    required this.value,
    required this.formattedValue,
    required this.trend,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String username;
  final int rank;
  final double value;
  final String formattedValue;
  final int trend;
  final String? avatarUrl;
}

class SportLeaderboard {
  const SportLeaderboard({
    required this.id,
    required this.sportId,
    required this.title,
    required this.metric,
    required this.unit,
    required this.period,
    required this.entries,
    required this.generatedAt,
    required this.audit,
  });

  final String id;
  final String sportId;
  final String title;
  final String metric;
  final String unit;
  final SportLeaderboardPeriod period;
  final List<SportLeaderboardEntry> entries;
  final DateTime generatedAt;
  final EntityAudit audit;
}
