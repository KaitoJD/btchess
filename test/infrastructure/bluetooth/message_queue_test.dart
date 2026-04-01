import 'package:flutter_test/flutter_test.dart';
import 'package:btchess/infrastructure/bluetooth/message_queue.dart';
import 'package:btchess/infrastructure/bluetooth/message_models.dart';

void main() {
  group('MessageQueue', () {
    late MessageQueue queue;

    setUp(() {
      queue = MessageQueue(maxSize: 5);
    });

    group('enqueue and dequeue', () {
      test('enqueue adds message and dequeue retrieves it', () {
        const msg = DrawOfferMessage(messageId: 1);
        queue.enqueue(msg);
        expect(queue.length, 1);
        expect(queue.isEmpty, isFalse);

        final dequeued = queue.dequeue();
        expect(dequeued, isNotNull);
        expect(dequeued!.message, isA<DrawOfferMessage>());
        expect(queue.isEmpty, isTrue);
      });

      test('dequeue returns null when empty', () {
        expect(queue.dequeue(), isNull);
      });
    });

    group('priority ordering', () {
      test('dequeues high priority before normal', () {
        const normalMsg = DrawOfferMessage(messageId: 1);
        const highMsg = PingMessage(messageId: 2, timestamp: 0);

        queue.enqueue(normalMsg);
        queue.enqueue(highMsg, priority: MessagePriority.high);

        final first = queue.dequeue();
        expect(first!.priority, MessagePriority.high);

        final second = queue.dequeue();
        expect(second!.priority, MessagePriority.normal);
      });

      test('dequeues normal priority before low', () {
        const lowMsg = DrawOfferMessage(messageId: 1);
        const normalMsg = ResignMessage(messageId: 2);

        queue.enqueue(lowMsg, priority: MessagePriority.low);
        queue.enqueue(normalMsg);

        final first = queue.dequeue();
        expect(first!.priority, MessagePriority.normal);
      });

      test('FIFO within same priority', () {
        const msg1 = DrawOfferMessage(messageId: 1);
        const msg2 = DrawOfferMessage(messageId: 2);
        const msg3 = DrawOfferMessage(messageId: 3);

        queue.enqueue(msg1);
        queue.enqueue(msg2);
        queue.enqueue(msg3);

        expect(queue.dequeue()!.message.messageId, 1);
        expect(queue.dequeue()!.message.messageId, 2);
        expect(queue.dequeue()!.message.messageId, 3);
      });
    });

    group('capacity', () {
      test('isFull returns true at max capacity', () {
        for (int i = 0; i < 5; i++) {
          queue.enqueue(DrawOfferMessage(messageId: i));
        }
        expect(queue.isFull, isTrue);
        expect(queue.length, 5);
      });

      test('enqueue beyond max size drops lowest priority', () {
        // Fill with low priority
        for (int i = 0; i < 5; i++) {
          queue.enqueue(
            DrawOfferMessage(messageId: i),
            priority: MessagePriority.low,
          );
        }

        // Add high priority — should drop a low priority message
        queue.enqueue(
          const PingMessage(messageId: 99, timestamp: 0),
          priority: MessagePriority.high,
        );

        expect(queue.length, 5);

        // First out should be the high priority
        final first = queue.dequeue();
        expect(first!.priority, MessagePriority.high);
      });
    });

    group('peek', () {
      test('returns next message without removing', () {
        const msg = DrawOfferMessage(messageId: 1);
        queue.enqueue(msg);

        final peeked = queue.peek();
        expect(peeked, isNotNull);
        expect(queue.length, 1); // still in queue
      });

      test('returns null when empty', () {
        expect(queue.peek(), isNull);
      });
    });

    group('clear', () {
      test('removes all messages', () {
        queue.enqueue(const DrawOfferMessage(messageId: 1));
        queue.enqueue(const DrawOfferMessage(messageId: 2));
        queue.clear();
        expect(queue.isEmpty, isTrue);
        expect(queue.length, 0);
      });
    });

    group('removeWhere', () {
      test('removes matching messages', () {
        queue.enqueue(const DrawOfferMessage(messageId: 1));
        queue.enqueue(const ResignMessage(messageId: 2));
        queue.enqueue(const DrawOfferMessage(messageId: 3));

        queue.removeWhere((q) => q.message is DrawOfferMessage);
        expect(queue.length, 1);
        expect(queue.dequeue()!.message, isA<ResignMessage>());
      });
    });
  });
}

