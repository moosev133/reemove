import '../../domain/entities/sport_leaderboard.dart';
import '../dto/sport_leaderboard_dto.dart';

extension SportLeaderboardDtoMapper on SportLeaderboardDto {
  SportLeaderboard toDomain() => SportLeaderboard(
    id: id,
    sportId: sportId,
    title: title,
    metric: metric,
    unit: unit,
    period: SportLeaderboardPeriod.values.byName(period),
    entries: entries
        .map(
          (SportLeaderboardEntryDto item) => SportLeaderboardEntry(
            userId: item.userId,
            displayName: item.displayName,
            username: item.username,
            rank: item.rank,
            value: item.value,
            formattedValue: item.formattedValue,
            trend: item.trend,
            avatarUrl: item.avatarUrl,
          ),
        )
        .toList(growable: false),
    generatedAt: generatedAt,
    audit: audit.toDomain(),
  );
}
