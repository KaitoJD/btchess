abstract class TimingConstants {
  // Timeouts

  static const int ackTimeoutMs = 3000;
  static const int chunkReassemblyTimeoutMs = 10000;
  static const int pingIntervalMs = 15000;
  static const int disconnectTimeoutMs = 30000;
  static const int connectionTimeoutMs = 10000;
  static const int handshakeTimeoutMs = 8000;
  static const int peripheralInitSettleDelayMs = 250;
  static const int peripheralServiceAddTimeoutMs = 6000;
  static const int peripheralServiceAddRetryDelayMs = 600;
  static const int peripheralHandshakeForwardDelayMs = 150;
  static const int peripheralServiceReadyDelayMs = 400;

  // Retries

  static const int maxMoveRetries = 2;
  static const int totalMoveAttempts = 3;
  static const List<int> retryBackoffMs = [500, 1000];

  // Rate Limiting

  static const int maxMovesPerSecond = 2;
  static const int drawOfferCooldownMs = 30000;
  static const int syncRequestCooldownMs = 5000;
}