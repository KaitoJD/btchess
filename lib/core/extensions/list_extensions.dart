// List utility extensions

extension ListExtensions<T> on List<T> {
  // Returns the last element, or null if the list is empty.
  T? get lastOrNull => isEmpty ? null : last;

  // Returns the first element, or null if the list is empty.
  T? get firstOrNull => isEmpty ? null : first;

  // Returns the first element matching [test], or null if none found.
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }

  // Splits the list into chunks of [size].
  //
  // The last chunk may have fewer elements if the list length
  // is not evenly divisible by [size].
  List<List<T>> chunked(int size) {
    if (size <= 0) throw ArgumentError('Chunk size must be positive, got $size');
    final chunks = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      final end = (i + size > length) ? length : i + size;
      chunks.add(sublist(i, end));
    }
    return chunks;
  }
}
