import 'package:flutter_test/flutter_test.dart';
import 'package:voiceapp/models/message.dart';

void main() {
  group('Message Model', () {
    test('creates message with required fields', () {
      final timestamp = DateTime(2024);
      final message = Message(
        id: 'test-id',
        role: MessageRole.user,
        content: 'Hello world',
        timestamp: timestamp,
      );

      expect(message.id, 'test-id');
      expect(message.role, MessageRole.user);
      expect(message.content, 'Hello world');
      expect(message.timestamp, timestamp);
      expect(message.isComplete, true);
    });

    test('creates message with isComplete flag', () {
      final timestamp = DateTime(2024);
      final message = Message(
        id: 'test-id',
        role: MessageRole.assistant,
        content: 'In progress...',
        timestamp: timestamp,
        isComplete: false,
      );

      expect(message.isComplete, false);
    });

    test('copyWith updates content', () {
      final timestamp = DateTime(2024);
      final original = Message(
        id: 'test-id',
        role: MessageRole.user,
        content: 'Original',
        timestamp: timestamp,
      );

      final updated = original.copyWith(content: 'Updated');

      expect(updated.id, 'test-id');
      expect(updated.role, MessageRole.user);
      expect(updated.content, 'Updated');
      expect(updated.timestamp, timestamp);
      expect(updated.isComplete, true);
    });

    test('copyWith updates isComplete', () {
      final timestamp = DateTime(2024);
      final original = Message(
        id: 'test-id',
        role: MessageRole.assistant,
        content: 'Streaming...',
        timestamp: timestamp,
        isComplete: false,
      );

      final updated = original.copyWith(isComplete: true);

      expect(updated.content, 'Streaming...');
      expect(updated.isComplete, true);
    });

    test('copyWith updates both content and isComplete', () {
      final timestamp = DateTime(2024);
      final original = Message(
        id: 'test-id',
        role: MessageRole.assistant,
        content: 'Partial',
        timestamp: timestamp,
        isComplete: false,
      );

      final updated = original.copyWith(
        content: 'Complete message',
        isComplete: true,
      );

      expect(updated.content, 'Complete message');
      expect(updated.isComplete, true);
    });

    test('copyWith preserves unchanged fields', () {
      final timestamp = DateTime(2024);
      final original = Message(
        id: 'test-id',
        role: MessageRole.user,
        content: 'Hello',
        timestamp: timestamp,
      );

      final updated = original.copyWith();

      expect(updated.id, original.id);
      expect(updated.role, original.role);
      expect(updated.content, original.content);
      expect(updated.timestamp, original.timestamp);
      expect(updated.isComplete, original.isComplete);
    });
  });

  group('MessageRole Enum', () {
    test('has expected values', () {
      expect(MessageRole.values.length, 3);
      expect(MessageRole.values, contains(MessageRole.user));
      expect(MessageRole.values, contains(MessageRole.assistant));
      expect(MessageRole.values, contains(MessageRole.system));
    });
  });
}
