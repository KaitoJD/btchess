class AppException implements Exception {
  const AppException(
    this.message,
    {
      this.code,
      this.originalError,
      this.stackTrace,
    }
  );

  final String message;
  final String? code;
  final Object? originalError;
  final StackTrace? stackTrace;

  @override
  String toString() => 'AppExeption: $message${code != null ? ' ($code)' : ''}';
}