import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/dto/entity_audit_dto.dart';
import '../../../../core/database/firestore_parser.dart';

class AppConfigurationDto {
  const AppConfigurationDto({
    required this.id,
    required this.maintenanceMode,
    required this.minimumSupportedBuild,
    required this.latestBuild,
    required this.defaultDiscoveryRadiusKm,
    required this.supportedCountryCodes,
    required this.termsVersion,
    required this.privacyVersion,
    required this.maxUploadBytes,
    required this.audit,
  });

  factory AppConfigurationDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('App configuration ${snapshot.id} has no data.');
    }
    final FirestoreMap uploadLimits = FirestoreParser.map(
      data,
      'maxUploadBytes',
    );
    return AppConfigurationDto(
      id: snapshot.id,
      maintenanceMode: FirestoreParser.boolean(
        data,
        'maintenanceMode',
        fallback: false,
      ),
      minimumSupportedBuild: FirestoreParser.integer(
        data,
        'minimumSupportedBuild',
        fallback: 1,
      ),
      latestBuild: FirestoreParser.integer(data, 'latestBuild', fallback: 1),
      defaultDiscoveryRadiusKm: FirestoreParser.number(
        data,
        'defaultDiscoveryRadiusKm',
        fallback: 25,
      ),
      supportedCountryCodes: FirestoreParser.stringList(
        data,
        'supportedCountryCodes',
      ),
      termsVersion: FirestoreParser.string(data, 'termsVersion', fallback: '1'),
      privacyVersion: FirestoreParser.string(
        data,
        'privacyVersion',
        fallback: '1',
      ),
      maxUploadBytes: uploadLimits.map((String key, Object? value) {
        if (value is! num) {
          throw FormatException('Upload limit "$key" must be numeric.');
        }
        return MapEntry<String, int>(key, value.toInt());
      }),
      audit: EntityAuditDto.fromMap(data),
    );
  }

  final String id;
  final bool maintenanceMode;
  final int minimumSupportedBuild;
  final int latestBuild;
  final double defaultDiscoveryRadiusKm;
  final List<String> supportedCountryCodes;
  final String termsVersion;
  final String privacyVersion;
  final Map<String, int> maxUploadBytes;
  final EntityAuditDto audit;

  FirestoreMap toFirestore([SetOptions? _]) => <String, Object?>{
    'maintenanceMode': maintenanceMode,
    'minimumSupportedBuild': minimumSupportedBuild,
    'latestBuild': latestBuild,
    'defaultDiscoveryRadiusKm': defaultDiscoveryRadiusKm,
    'supportedCountryCodes': supportedCountryCodes,
    'termsVersion': termsVersion,
    'privacyVersion': privacyVersion,
    'maxUploadBytes': maxUploadBytes,
    ...audit.toMap(),
  };
}
