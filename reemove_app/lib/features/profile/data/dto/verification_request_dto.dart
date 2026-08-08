import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/firestore_parser.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/verification_request.dart';

class VerificationRequestDto {
  const VerificationRequestDto({
    required this.id,
    required this.uid,
    required this.requestedType,
    required this.status,
    required this.legalName,
    required this.summary,
    required this.evidence,
    this.submittedAt,
    this.reviewedAt,
    this.rejectionReason,
  });

  factory VerificationRequestDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? _,
  ) {
    final Map<String, dynamic> data =
        snapshot.data() ?? const <String, dynamic>{};
    final List<VerificationEvidence> evidence = data['evidence'] is List
        ? (data['evidence'] as List<dynamic>)
              .whereType<Map>()
              .map(_evidenceFromMap)
              .where((VerificationEvidence item) => item.storagePath.isNotEmpty)
              .toList(growable: false)
        : const <VerificationEvidence>[];
    return VerificationRequestDto(
      id: snapshot.id,
      uid: FirestoreParser.string(data, 'uid'),
      requestedType: FirestoreParser.string(
        data,
        'requestedType',
        fallback: 'athlete',
      ),
      status: FirestoreParser.string(data, 'status', fallback: 'pending'),
      legalName: FirestoreParser.string(data, 'legalName'),
      summary: FirestoreParser.string(data, 'summary'),
      evidence: evidence,
      submittedAt: FirestoreParser.nullableDateTime(data, 'submittedAt'),
      reviewedAt: FirestoreParser.nullableDateTime(data, 'reviewedAt'),
      rejectionReason: FirestoreParser.nullableString(data, 'rejectionReason'),
    );
  }

  static VerificationEvidence _evidenceFromMap(Map<dynamic, dynamic> item) {
    final String kindRaw = item['documentKind'] is String
        ? item['documentKind'] as String
        : 'other';
    final VerificationDocumentKind kind = VerificationDocumentKind.values
        .cast<VerificationDocumentKind?>()
        .firstWhere(
          (VerificationDocumentKind? value) => value?.name == kindRaw,
          orElse: () => VerificationDocumentKind.other,
        )!;
    DateTime? parseDate(Object? value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value.trim());
      }
      return null;
    }

    return VerificationEvidence(
      storagePath: item['storagePath'] is String
          ? item['storagePath'] as String
          : '',
      label: item['label'] is String ? item['label'] as String : '',
      documentKind: kind,
      contentType: item['contentType'] is String
          ? item['contentType'] as String
          : null,
      sizeBytes: item['sizeBytes'] is num
          ? (item['sizeBytes'] as num).toInt()
          : null,
      issuer: item['issuer'] is String ? item['issuer'] as String : null,
      issuedAt: parseDate(item['issuedAt']),
      expiresAt: parseDate(item['expiresAt']),
    );
  }

  final String id;
  final String uid;
  final String requestedType;
  final String status;
  final String legalName;
  final String summary;
  final List<VerificationEvidence> evidence;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  VerificationRequest toDomain() {
    final VerificationType type = VerificationType.values
        .cast<VerificationType?>()
        .firstWhere(
          (VerificationType? value) => value?.name == requestedType,
          orElse: () => VerificationType.athlete,
        )!;
    final VerificationRequestStatus parsedStatus = VerificationRequestStatus
        .values
        .cast<VerificationRequestStatus?>()
        .firstWhere(
          (VerificationRequestStatus? value) => value?.name == status,
          orElse: () => VerificationRequestStatus.pending,
        )!;
    return VerificationRequest(
      id: id,
      uid: uid,
      requestedType: type,
      status: parsedStatus,
      legalName: legalName,
      summary: summary,
      evidence: evidence,
      submittedAt: submittedAt,
      reviewedAt: reviewedAt,
      rejectionReason: rejectionReason,
    );
  }
}
