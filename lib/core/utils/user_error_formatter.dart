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

    final actionableMessage = _extractActionableMessageFromString(message);
    if (actionableMessage != null) {
      return actionableMessage;
    }

    return genericErrorMessage;
  }

  static bool isUserFixableMessage(String message) {
    return _extractActionableMessageFromString(message) != null;
  }

  static String? fixHintForMessage(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('bluetooth is turned off')) {
      return 'Turn on Bluetooth in Quick Settings or device Settings, then retry.';
    }
    if (lower.contains('permanently denied') ||
        lower.contains('enable it in settings')) {
      return 'Open Settings and allow Bluetooth permissions for this app.';
    }
    if (lower.contains('permissions not granted') ||
        lower.contains('permission')) {
      return 'Grant Bluetooth permissions and try again.';
    }
    if (lower.contains('not your turn')) {
      return 'Wait for your opponent to move, then try again.';
    }
    if (lower.contains('invalid move') || lower.contains('illegal move')) {
      return 'Choose a legal move. You can enable legal move highlights in Settings.';
    }
    if (lower.contains('connection lost') || lower.contains('disconnected')) {
      return 'Move devices closer, keep Bluetooth on, then reconnect.';
    }
    if (lower.contains('session expired')) {
      return 'Return to the lobby and create or join a new game session.';
    }
    if (lower.contains('too many requests') || lower.contains('rate limit')) {
      return 'Wait a moment before trying the same action again.';
    }
    if (lower.contains('sync required')) {
      return 'Request sync to refresh the latest game state.';
    }
    if (lower.contains('game has ended')) {
      return 'Start a new game or request a rematch.';
    }

    return null;
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
      return _extractActionableMessageFromString(error.message);
    }

    return _extractActionableMessageFromString(error.toString());
  }

  static String? _extractActionableMessageFromString(String message) {
    final normalized = _stripTypePrefix(message).trim();
    final lower = normalized.toLowerCase();

    if (lower.contains('bluetooth is turned off')) {
      return 'Bluetooth is turned off';
    }
    if (lower.contains('permanently denied') ||
        lower.contains('enable it in settings')) {
      return 'Bluetooth permission is permanently denied. Please enable it in Settings.';
    }
    if (lower.contains('permissions not granted') ||
        lower == 'bluetooth permission is required') {
      return 'Bluetooth permissions not granted';
    }
    if (lower.contains('not your turn')) {
      return 'Not your turn';
    }
    if (lower.contains('invalid move') || lower.contains('illegal move')) {
      return 'Invalid move';
    }
    if (lower.contains('connection lost')) {
      return 'Connection lost';
    }
    if (lower.contains('disconnected')) {
      return 'Disconnected';
    }
    if (lower.contains('session expired')) {
      return 'Session expired';
    }
    if (lower.contains('too many requests') || lower.contains('rate limit')) {
      return 'Too many requests, please wait';
    }
    if (lower.contains('sync required')) {
      return 'Sync required';
    }
    if (lower.contains('game has ended')) {
      return 'Game has ended';
    }
    if (lower.contains('game not ready yet')) {
      return 'Game not ready yet';
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
}