import 'dart:async';
import 'dart:collection';
import 'message_models.dart';

enum MessagePriority {
  high,
  normal,
  low,
}

class QueuedMessage {
  QueuedMessage({
    required this.message,
    required this.priority,
    DateTime? queuedAt,
    this.attempts = 0,
    this.completer,
  }) : queuedAt = queuedAt ?? DateTime.now();

  final BleMessage message;
  final MessagePriority priority;
  final DateTime queuedAt;
  int attempts;
  Completer<void>? completer;
}

class MessageQueue {
  MessageQueue({this.maxSize = 100});

  final Queue<QueuedMessage> _highPriority = Queue();
  final Queue<QueuedMessage> _normalPriority = Queue();
  final Queue<QueuedMessage> _lowPriority = Queue();

  // Maximum queue size
  final int maxSize;

  // Total number of queued messages
  int get length => _highPriority.length + _normalPriority.length + _lowPriority.length;

  // Whether the queue is empty
  bool get isEmpty => length == 0;

  // Whether the queue is full
  bool get isFull => length >= maxSize;

  // Enqueues a message
  void enqueue(BleMessage message, {MessagePriority priority = MessagePriority.normal}) {
    if (isFull) {
      if (_lowPriority.isNotEmpty) {
        _lowPriority.removeFirst();
      } else if (_normalPriority.isNotEmpty) {
        _normalPriority.removeFirst();
      } else {
        return;
      }
    }

    final queued = QueuedMessage(message: message, priority: priority);

    switch (priority) {
      case MessagePriority.high:
        _highPriority.addLast(queued);
        break;
      case MessagePriority.normal:
        _normalPriority.addLast(queued);
        break;
      case MessagePriority.low:
        _lowPriority.addLast(queued);
        break;
    }
  }

  // Dequeues the next message (highest priority first)
  QueuedMessage? dequeue() {
    if (_highPriority.isNotEmpty) {
      return _highPriority.removeFirst();
    }
    if (_normalPriority.isNotEmpty) {
      return _normalPriority.removeFirst();
    }
    if (_lowPriority.isNotEmpty) {
      return _lowPriority.removeFirst();
    }
    return null;
  }

  // Peeks at the next message without removing it
  QueuedMessage? peek() {
    if (_highPriority.isNotEmpty) {
      return _highPriority.first;
    }
    if (_normalPriority.isNotEmpty) {
      return _normalPriority.first;
    }
    if (_lowPriority.isNotEmpty) {
      return _lowPriority.first;
    }
    return null;
  }

  // Clears all messages
  void clear() {
    _highPriority.clear();
    _normalPriority.clear();
    _lowPriority.clear();
  }

  // Removes messages matching a predicate
  void removeWhere(bool Function(QueuedMessage) test) {
    _highPriority.removeWhere(test);
    _normalPriority.removeWhere(test);
    _lowPriority.removeWhere(test);
  }
}