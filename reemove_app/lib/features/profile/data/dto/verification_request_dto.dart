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
    required this.submittedAt,
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
              .whereType<Map<Object?, Object?>>()
              .map(
                (Map<Object?, Object?> item) => VerificationEvidence(
                  storagePath: item['storagePath'] is String
                      ? item['storagePath'] as String
                      : '',
                  label: item['label'] is String ? item['label'] as String : '',
                ),
              )
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
      submittedAt: FirestoreParser.dateTime(data, 'submittedAt'),
      reviewedAt: FirestoreParser.nullableDateTime(data, 'reviewedAt'),
      rejectionReason: FirestoreParser.nullableString(data, 'rejectionReason'),
    );
  }

  final String id;
  final String uid;
  final String requestedType;
  final String status;
  final String legalName;
  final String summary;
  final List<VerificationEvidence> evidence;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  VerificationRequest toDomain() => VerificationRequest(
    id: id,
    uid: uid,
    requestedType: VerificationType.values.byName(requestedType),
    status: VerificationRequestStatus.values.byName(status),
    legalName: legalName,
    summary: summary,
    evidence: evidence,
    submittedAt: submittedAt,
    reviewedAt: reviewedAt,
    rejectionReason: rejectionReason,
  );
}
