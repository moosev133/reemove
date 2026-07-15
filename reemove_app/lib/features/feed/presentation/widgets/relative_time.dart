String relativeTime(DateTime value, {DateTime? now}) {
  final DateTime current = (now ?? DateTime.now()).toUtc();
  final Duration difference = current.difference(value.toUtc());
  if (difference.isNegative || difference.inSeconds < 45) {
    return 'now';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours}h';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d';
  }
  if (difference.inDays < 365) {
    final int weeks = (difference.inDays / 7).floor();
    return '${weeks}w';
  }
  final int years = (difference.inDays / 365).floor();
  return '${years}y';
}
