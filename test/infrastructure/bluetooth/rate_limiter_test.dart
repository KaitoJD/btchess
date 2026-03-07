import 'package:flutter_test/flutter_test.dart';
import 'package:btchess/infrastructure/bluetooth/rate_limiter.dart';

void main() {
  group('RateLimiter', () {
    late RateLimiter limiter;

    setUp(() {
      limiter = RateLimiter();
    });

    group('move rate limiting', () {
      test('allows first move', () {
        expect(limiter.canSend('move'), isTrue);
      });

      test('allows second move within window', () {
        limiter.recordSend('move');
        expect(limiter.canSend('move'), isTrue);
      });

      test('tryAcquire returns true and records', () {
        expect(limiter.tryAcquire('move'), isTrue);
      });
    });

    group('drawOffer rate limiting', () {
      test('allows first draw offer', () {
        expect(limiter.canSend('drawOffer'), isTrue);
      });

      test('blocks second draw offer within cooldown', () {
        limiter.recordSend('drawOffer');
        expect(limiter.canSend('drawOffer'), isFalse);
      });

      test('getWaitTimeMs returns positive value during cooldown', () {
        limiter.recordSend('drawOffer');
        expect(limiter.getWaitTimeMs('drawOffer'), greaterThan(0));
      });
    });

    group('syncRequest rate limiting', () {
      test('allows first sync request', () {
        expect(limiter.canSend('syncRequest'), isTrue);
      });

      test('blocks second sync request within cooldown', () {
        limiter.recordSend('syncRequest');
        expect(limiter.canSend('syncRequest'), isFalse);
      });
    });

    group('reset', () {
      test('reset clears all state', () {
        limiter.recordSend('drawOffer');
        expect(limiter.canSend('drawOffer'), isFalse);
        limiter.reset();
        expect(limiter.canSend('drawOffer'), isTrue);
      });

      test('resetType clears only specific type', () {
        limiter.recordSend('drawOffer');
        limiter.recordSend('syncRequest');

        limiter.resetType('drawOffer');
        expect(limiter.canSend('drawOffer'), isTrue);
        expect(limiter.canSend('syncRequest'), isFalse);
      });
    });

    group('unknown type', () {
      test('allows unknown message type', () {
        expect(limiter.canSend('unknown'), isTrue);
      });

      test('getWaitTimeMs returns 0 for unknown type', () {
        expect(limiter.getWaitTimeMs('unknown'), 0);
      });
    });
  });
}

