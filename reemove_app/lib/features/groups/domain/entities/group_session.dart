import 'group_enums.dart';
import 'group_location.dart';

class GroupSession {
  const GroupSession({
    required this.sessionId,
    required this.title,
    required this.activity,
    required this.description,
    required this.location,
    required this.capacity,
    required this.status,
    this.startAt,
    this.endAt,
    this.createdBy,
  });

  final String sessionId;
  final String title;
  final String activity;
  final String description;
  final DateTime? startAt;
  final DateTime? endAt;
  final GroupLocation location;
  final int capacity;
  final GroupSessionStatus status;
  final String? createdBy;

  bool get isCancelled => status == GroupSessionStatus.cancelled;
  bool get isUpcoming =>
      status == GroupSessionStatus.scheduled &&
      (startAt?.isAfter(DateTime.now().toUtc()) ?? false);
}
