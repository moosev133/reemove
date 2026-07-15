import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/database/dto/entity_audit_dto.dart';
import 'package:reemove/features/sports/shared/data/dto/sport_community_dto.dart';
import 'package:reemove/features/sports/shared/data/dto/sport_leaderboard_dto.dart';
import 'package:reemove/features/sports/shared/data/mappers/sport_community_mapper.dart';
import 'package:reemove/features/sports/shared/data/mappers/sport_leaderboard_mapper.dart';
import 'package:reemove/features/sports/shared/domain/entities/sport_community.dart';
import 'package:reemove/features/sports/shared/domain/entities/sport_leaderboard.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 7, 14, 12);
  final EntityAuditDto audit = EntityAuditDto(
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
  );

  test('maps community capacity, policy, and ownership state', () {
    final SportCommunity community = SportCommunityDto(
      id: 'weekend-fc',
      sportId: 'football',
      ownerId: 'owner',
      name: 'Weekend FC',
      description: 'Weekly local football.',
      type: 'team',
      joinPolicy: 'approvalRequired',
      memberCount: 20,
      capacity: 20,
      tags: const <String>['weekend'],
      city: 'Tamra',
      countryCode: 'IL',
      isVerified: true,
      visibility: 'public',
      moderationState: 'active',
      audit: audit,
    ).toDomain();

    expect(community.type, SportCommunityType.team);
    expect(community.joinPolicy, SportCommunityJoinPolicy.approvalRequired);
    expect(community.isFull, isTrue);
  });

  test('maps leaderboard entries without losing rank metadata', () {
    final SportLeaderboard leaderboard = SportLeaderboardDto(
      id: 'running-weekly',
      sportId: 'running',
      title: 'Weekly Distance',
      metric: 'distanceKm',
      unit: 'km',
      period: 'weekly',
      entries: const <SportLeaderboardEntryDto>[
        SportLeaderboardEntryDto(
          userId: 'runner',
          displayName: 'Demo Runner',
          username: 'demo_runner',
          rank: 1,
          value: 24.5,
          formattedValue: '24.5 km',
          trend: 2,
        ),
      ],
      generatedAt: now,
      audit: audit,
    ).toDomain();

    expect(leaderboard.period, SportLeaderboardPeriod.weekly);
    expect(leaderboard.entries.single.rank, 1);
    expect(leaderboard.entries.single.trend, 2);
  });
}
