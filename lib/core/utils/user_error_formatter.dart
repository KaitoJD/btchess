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

    final actionableMessage = _extractActionableMessage(error);
    if (actionableMessage != null) {
      return actionableMessage;
    }

    return genericErrorMessage;
  }

  static String formatMessage(String message) {
    if (_debugModeEnabled) {
      return message;
    }

    if (_isActionableMessage(message)) {
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

  static String? _extractActionableMessage(Object error) {
    if (error is AppException) {
      if (_isActionableMessage(error.message)) {
        return error.message;
      }
      return null;
    }

    final raw = error.toString();
    final normalized = _stripTypePrefix(raw);

    if (_isActionableMessage(normalized)) {
      return normalized;
    }
    if (_isActionableMessage(raw)) {
      return raw;
    }

    return null;
  }

  static String _stripTypePrefix(String message) {
    final separator = message.indexOf(': ');
    if (separator <= 0) {
      return message;
    }
    return message.substring(separator + 2);
  }

  static bool _isActionableMessage(String message) {
    final lower = message.toLowerCase();

    return lower.contains('bluetooth is turned off') ||
        lower.contains('permission') ||
        lower.contains('enable it in settings') ||
        lower.contains('permissions not granted') ||
        lower.contains('not your turn') ||
        lower.contains('invalid move') ||
        lower.contains('game has ended') ||
        lower.contains('sync required') ||
        lower.contains('too many requests') ||
        lower.contains('connection lost') ||
        lower.contains('disconnected') ||
        lower.contains('game not ready yet') ||
        lower.contains('timeout');
  }
}