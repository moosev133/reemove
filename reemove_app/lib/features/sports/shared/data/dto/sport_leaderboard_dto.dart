import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/database/dto/entity_audit_dto.dart';
import '../../../../../core/database/firestore_parser.dart';

class SportLeaderboardEntryDto {
  const SportLeaderboardEntryDto({
    required this.userId,
    required this.displayName,
    required this.username,
    required this.rank,
    required this.value,
    required this.formattedValue,
    required this.trend,
    this.avatarUrl,
  });

  factory SportLeaderboardEntryDto.fromMap(FirestoreMap data) =>
      SportLeaderboardEntryDto(
        userId: FirestoreParser.string(data, 'userId'),
        displayName: FirestoreParser.string(
          data,
          'displayName',
          fallback: 'Athlete',
        ),
        username: FirestoreParser.string(data, 'username', fallback: ''),
        rank: FirestoreParser.integer(data, 'rank'),
        value: FirestoreParser.number(data, 'value'),
        formattedValue: FirestoreParser.string(
          data,
          'formattedValue',
          fallback: '',
        ),
        trend: FirestoreParser.integer(data, 'trend', fallback: 0),
        avatarUrl: FirestoreParser.nullableString(data, 'avatarUrl'),
      );

  final String userId;
  final String displayName;
  final String username;
  final int rank;
  final double value;
  final String formattedValue;
  final int trend;
  final String? avatarUrl;
}

class SportLeaderboardDto {
  const SportLeaderboardDto({
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

  factory SportLeaderboardDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Leaderboard ${snapshot.id} has no data.');
    }
    return SportLeaderboardDto(
      id: snapshot.id,
      sportId: FirestoreParser.string(data, 'sportId'),
      title: FirestoreParser.string(data, 'title'),
      metric: FirestoreParser.string(data, 'metric'),
      unit: FirestoreParser.string(data, 'unit', fallback: ''),
      period: FirestoreParser.string(data, 'period', fallback: 'weekly'),
      entries: FirestoreParser.mapList(
        data,
        'topEntries',
      ).map(SportLeaderboardEntryDto.fromMap).toList(growable: false),
      generatedAt: FirestoreParser.dateTime(data, 'generatedAt'),
      audit: EntityAuditDto.fromMap(data),
    );
  }

  final String id;
  final String sportId;
  final String title;
  final String metric;
  final String unit;
  final String period;
  final List<SportLeaderboardEntryDto> entries;
  final DateTime generatedAt;
  final EntityAuditDto audit;
}
