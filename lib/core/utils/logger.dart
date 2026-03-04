import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'binary_utils.dart';

// Log level hierarchy (higher index = more verbose)
enum LogLevel {
  off,
  error,
  warn,
  info,
  debug,
  verbose;

  bool operator >=(LogLevel other) => index >= other.index;
  bool operator <=(LogLevel other) => index <= other.index;
}

// Structured logger with configurable levels and BLE hex message support.
//
// Usage:
//   Logger.setLevel(LogLevel.debug);
//   Logger.info('Game started', tag: 'GameController');
//   Logger.bleMessage(bytes, label: 'MOVE received');
abstract class Logger {
  static LogLevel _level = kDebugMode ? LogLevel.debug : LogLevel.off;

  // Current log level
  static LogLevel get level => _level;

  // Sets the minimum log level. Messages below this level are discarded.
  static void setLevel(LogLevel level) {
    _level = level;
  }

  // Logs an error message (level 1)
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (_level.index < LogLevel.error.index) return;
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  // Logs a warning message (level 2)
  static void warn(String message, {String? tag}) {
    if (_level.index < LogLevel.warn.index) return;
    _log(LogLevel.warn, message, tag: tag);
  }

  // Logs an informational message (level 3)
  static void info(String message, {String? tag}) {
    if (_level.index < LogLevel.info.index) return;
    _log(LogLevel.info, message, tag: tag);
  }

  // Logs a debug message (level 4)
  static void debug(String message, {String? tag}) {
    if (_level.index < LogLevel.debug.index) return;
    _log(LogLevel.debug, message, tag: tag);
  }

  // Logs a verbose message (level 5)
  static void verbose(String message, {String? tag}) {
    if (_level.index < LogLevel.verbose.index) return;
    _log(LogLevel.verbose, message, tag: tag);
  }

  // Logs a BLE message in hex format with interpreted fields.
  //
  // Outputs both the raw hex bytes and a human-readable label.
  // Only logs at debug level or above.
  static void bleMessage(Uint8List bytes, {String? label}) {
    if (_level.index < LogLevel.debug.index) return;

    final hex = BinaryUtils.toHexString(bytes);
    final size = bytes.length;
    final prefix = label != null ? '$label: ' : '';
    _log(LogLevel.debug, '$prefix[$size bytes] $hex', tag: 'BLE');
  }

  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;

    final prefix = tag != null ? '$tag: ' : '';
    final levelLabel = level.name.toUpperCase();
    final formatted = '[$levelLabel] $prefix$message';

    developer.log(
      formatted,
      name: tag ?? 'BTChess',
      level: _developerLogLevel(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  // Maps LogLevel to dart:developer log level values
  static int _developerLogLevel(LogLevel level) {
    return switch (level) {
      LogLevel.off => 0,
      LogLevel.error => 1000,
      LogLevel.warn => 900,
      LogLevel.info => 800,
      LogLevel.debug => 500,
      LogLevel.verbose => 300,
    };
  }
}
