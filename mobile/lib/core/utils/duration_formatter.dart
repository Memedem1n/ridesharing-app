String formatDurationMin(num? minutes) {
  final totalMinutes = (minutes ?? 0).round();
  if (totalMinutes <= 0) {
    return '0 dk';
  }

  final hours = totalMinutes ~/ 60;
  final mins = totalMinutes % 60;

  if (hours == 0) {
    return '$mins dk';
  }
  if (mins == 0) {
    return '$hours sa';
  }
  return '$hours sa $mins dk';
}
