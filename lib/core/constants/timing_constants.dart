abstract class TimingConstants {
  // Timeouts

  static const int ackTimeoutMs = 3000;
  static const int chunkReassemblyTimeoutMs = 10000;
  static const int pingIntervalMs = 15000;
  static const int disconnectTimeoutMs = 30000;
  static const int connectionTimeoutMs = 10000;
  static const int handshakeTimeoutMs = 5000;

  // Retries

  static const int maxMoveRetries = 2;
  static const int totalMoveAttempts = 3;
  static const List<int> retryBackoffMs = [500, 1000];

  // Rate Limiting

  static const int maxMovesPerSecond = 2;
  static const int drawOfferCooldownMs = 30000;
  static const int syncRequestCooldownMs = 5000;
}