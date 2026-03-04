import 'app_exception.dart';

// Base class for game logic exceptions
class GameException extends AppException {
  const GameException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

// Thrown when an invalid move is attempted
class InvalidMoveException extends GameException {
  const InvalidMoveException(
    super.message, {
    this.from,
    this.to,
    super.code,
  });

  final String? from;
  final String? to;

  @override
  String toString() =>
      'InvalidMoveException: $message${from != null && to != null ? ' ($from → $to)' : ''}';
}

// Thrown when an action is attempted on a game that has already ended
class GameEndedException extends GameException {
  const GameEndedException(
    super.message, {
    this.reason,
    super.code,
  });

  final String? reason;

  @override
  String toString() =>
      'GameEndedException: $message${reason != null ? ' (reason: $reason)' : ''}';
}

// Thrown when a BLE sync is required before the game can continue
class SyncRequiredException extends GameException {
  const SyncRequiredException(
    super.message, {
    super.code,
  });

  @override
  String toString() => 'SyncRequiredException: $message';
}
