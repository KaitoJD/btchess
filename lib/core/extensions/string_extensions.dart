// String utility extensions

extension StringExtensions on String {
  // Capitalizes the first character of the string.
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  // Capitalizes the first character of each word.
  String toTitleCase() {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize()).join(' ');
  }

  // Truncates the string to [maxLength] and appends [suffix] if truncated.
  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    final end = maxLength - suffix.length;
    if (end <= 0) return suffix.substring(0, maxLength);
    return '${substring(0, end)}$suffix';
  }
}

// Nullable string extensions
extension NullableStringExtensions on String? {
  // Returns true if the string is null or empty.
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  // Returns true if the string is not null and not empty.
  bool get isNotNullOrEmpty => !isNullOrEmpty;
}
