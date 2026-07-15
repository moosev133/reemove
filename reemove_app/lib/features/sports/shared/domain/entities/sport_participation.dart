enum SportsEventAttendanceStatus { none, attending, waitlisted, cancelled }

class SportsEventParticipation {
  const SportsEventParticipation({
    required this.eventId,
    required this.status,
    required this.updatedAt,
  });

  final String eventId;
  final SportsEventAttendanceStatus status;
  final DateTime updatedAt;
}
