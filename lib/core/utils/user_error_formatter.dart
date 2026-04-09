import '../errors/app_exception.dart';
import '../errors/ble_exception.dart';

abstract class UserErrorFormatter {
  static const String genericErrorMessage = 'Something went wrong :(';

  static bool _debugModeEnabled = false;

  static void setDebugMode({required bool enabled}) {
    _debugModeEnabled = enabled;
  }

  static String formatError(
    Object error, {
    String? context,
  }) {
    if (_debugModeEnabled) {
      return _buildDebugMessage(error, context: context);
    }

    return genericErrorMessage;
  }

  static String formatMessage(String message) {
    if (_debugModeEnabled) {
      return message;
    }

    return genericErrorMessage;
  }

  static String _buildDebugMessage(Object error, {String? context}) {
    final details = _detailsFromError(error);
    if (context == null || context.isEmpty) {
      return details;
    }
    return '$context: $details';
  }

  static String _detailsFromError(Object error) {
    if (error is BleProtocolException) {
      final code = error.errorCode != null
          ? ' (error: 0x${error.errorCode!.toRadixString(16)})'
          : '';
      return 'BleProtocolException: ${error.message}$code';
    }

    if (error is AppException) {
      final code = error.code != null ? ' (${error.code})' : '';
      return '${error.runtimeType}: ${error.message}$code';
    }

    return error.toString();
  }
}