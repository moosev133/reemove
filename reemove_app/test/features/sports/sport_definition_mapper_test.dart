import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/database/dto/entity_audit_dto.dart';
import 'package:reemove/features/sports/shared/data/dto/sport_definition_dto.dart';
import 'package:reemove/features/sports/shared/data/mappers/sport_definition_mapper.dart';

void main() {
  test('chooses localized sport names with an English fallback', () {
    final DateTime now = DateTime.utc(2026, 7, 13, 12);
    final sport = SportDefinitionDto(
      id: 'football',
      slug: 'football',
      localizedNames: const <String, String>{
        'en': 'Football',
        'ar': 'كرة القدم',
        'he': 'כדורגל',
      },
      iconKey: 'football',
      isEnabled: true,
      sortOrder: 10,
      supportedFeatures: const <String>['places', 'events'],
      audit: EntityAuditDto(createdAt: now, updatedAt: now, schemaVersion: 1),
    ).toDomain();

    expect(sport.displayName('ar'), 'كرة القدم');
    expect(sport.displayName('fr'), 'Football');
    expect(Timestamp.fromDate(sport.audit.createdAt).toDate().toUtc(), now);
  });
}
