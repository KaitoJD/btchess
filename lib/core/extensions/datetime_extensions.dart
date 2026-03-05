// DateTime utility extensions

extension DateTimeExtensions on DateTime {
  // Formats as PGN standard date: 'YYYY.MM.DD'
  String toPgnDate() {
    return '$year.${month.toString().padLeft(2, '0')}.${day.toString().padLeft(2, '0')}';
  }

  // Formats as ISO short date: 'YYYY-MM-DD'
  String toShortDate() {
    return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  // Formats as a short time: 'HH:MM'
  String toShortTime() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  // Returns a human-readable relative time string.
  //
  // Examples: 'just now', '5m ago', '2h ago', 'yesterday', 'Mar 1'
  String toRelative() {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.isNegative) return toShortDate();

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return _shortMonth();
  }

  String _shortMonth() {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[month - 1]} $day';
  }
}
