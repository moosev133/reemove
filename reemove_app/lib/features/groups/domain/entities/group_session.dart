import 'group_enums.dart';
import 'group_location.dart';

class GroupSessionRsvpCounts {
  const GroupSessionRsvpCounts({
    this.going = 0,
    this.maybe = 0,
    this.notGoing = 0,
  });

  final int going;
  final int maybe;
  final int notGoing;

  int get totalResponses => going + maybe + notGoing;
}

class GroupSession {
  const GroupSession({
    required this.sessionId,
    required this.title,
    required this.sessionType,
    required this.activity,
    required this.description,
    required this.location,
    required this.capacity,
    required this.status,
    this.startAt,
    this.endAt,
    this.createdBy,
    this.rsvpCounts = const GroupSessionRsvpCounts(),
    this.viewerRsvp,
  });

  final String sessionId;
  final String title;
  final GroupSessionType sessionType;
  final String activity;
  final String description;
  final DateTime? startAt;
  final DateTime? endAt;
  final GroupLocation location;
  final int capacity;
  final GroupSessionStatus status;
  final String? createdBy;
  final GroupSessionRsvpCounts rsvpCounts;
  final GroupSessionRsvpStatus? viewerRsvp;

  bool get isCancelled => status == GroupSessionStatus.cancelled;
  bool get isUpcoming =>
      status == GroupSessionStatus.scheduled &&
      (startAt?.isAfter(DateTime.now().toUtc()) ?? false);

  bool get isAtCapacity =>
      capacity > 0 && rsvpCounts.going >= capacity;
}
