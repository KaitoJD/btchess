import '../../core/constants/timing_constants.dart';

class RateLimiter {
  RateLimiter() {
    _configs['move'] = const _RateLimitConfig(
      maxPerSecond: TimingConstants.maxMovesPerSecond,
      windowMs: 100,
    );
    _configs['drawOffer'] = const _RateLimitConfig(
      maxPerSecond: 1,
      windowMs: TimingConstants.drawOfferCooldownMs,
    );
    _configs['syncRequest'] = const _RateLimitConfig(
      maxPerSecond: 1,
      windowMs: TimingConstants.syncRequestCooldownMs,
    );
  }

  // Rate limit config by message type
  final Map<String, _RateLimitConfig> _configs = {};
  
  // Timestamps of recent messages by type
  final Map<String, List<DateTime>> _timestamps = {};

  // Checks if a message of the given type can be sent
  bool canSend(String messageType) {
    final config = _configs[messageType];
    if (config == null) return true;

    _cleanupOldTimestamps(messageType, config.windowMs);

    final timestamps = _timestamps[messageType] ?? [];
    return timestamps.length < config.maxPerSecond;
  }

  // Records that a message was sent
  void recordSend(String messageType) {
    _timestamps[messageType] ??= [];
    _timestamps[messageType]!.add(DateTime.now());
  }

  // Checks if allowed and records if so
  bool tryAcquire(String messageType) {
    if (canSend(messageType)) {
      recordSend(messageType);
      return true;
    }
    return false;
  }

  // Returns milliseconds until next allowed send, or 0 if allowed now
  int getWaitTimeMs(String messageType) {
    final config = _configs[messageType];
    if (config == null) return 0;

    _cleanupOldTimestamps(messageType, config.windowMs);

    final timestamps = _timestamps[messageType] ?? [];
    if (timestamps.length < config.maxPerSecond) return 0;

    final oldest = timestamps.first;
    final waitUntil = oldest.add(Duration(milliseconds: config.windowMs));
    final waitMs = waitUntil.difference(DateTime.now()).inMilliseconds;

    return waitMs > 0 ? waitMs : 0;
  }

  // Resets the rate limiter state
  void reset() {
    _timestamps.clear();
  }

  // Resets rate limit for a specific message type
  void resetType(String messageType) {
    _timestamps.remove(messageType);
  }

  void _cleanupOldTimestamps(String messageType, int windowMs) {
    final timestamps = _timestamps[messageType];
    if (timestamps == null) return;

    final cutoff = DateTime.now().subtract(Duration(milliseconds: windowMs));
    timestamps.removeWhere((t) => t.isBefore(cutoff));
  }
}

class _RateLimitConfig {
  const _RateLimitConfig({
    required this.maxPerSecond,
    required this.windowMs,
  });

  final int maxPerSecond;
  final int windowMs;
}