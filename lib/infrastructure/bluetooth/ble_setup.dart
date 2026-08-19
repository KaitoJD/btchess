/// Fine-grained progress states for a single BLE setup attempt.
///
/// These phases deliberately describe setup rather than the long-lived game
/// connection.  A peer is only ready after service discovery, notification
/// subscription, and the protocol handshake have all completed.
enum BleSetupPhase {
  connecting,
  pairing,
  awaitingReconnect,
  discovering,
  subscribing,
  handshaking,
  ready,
  failed,
  cancelled,
}

extension BleSetupPhaseX on BleSetupPhase {
  bool get isTerminal =>
      this == BleSetupPhase.ready ||
      this == BleSetupPhase.failed ||
      this == BleSetupPhase.cancelled;
}

/// A setup transition emitted by a host or central connection attempt.
///
/// Do not put passkeys or full Bluetooth identifiers in [reason].  The
/// attempt id is enough to correlate diagnostic logs without exposing either.
class PeerSetupEvent {
  const PeerSetupEvent({
    required this.attemptId,
    required this.phase,
    required this.isHost,
    required this.platform,
    required this.occurredAt,
    this.reason,
  });

  final int attemptId;
  final BleSetupPhase phase;
  final bool isHost;
  final String platform;
  final DateTime occurredAt;
  final String? reason;

  @override
  String toString() {
    return 'PeerSetupEvent('
        'attempt=$attemptId, '
        'phase=${phase.name}, '
        'role=${isHost ? 'host' : 'client'}, '
        'platform=$platform'
        '${reason == null ? '' : ', reason=$reason'}'
        ')';
  }
}
