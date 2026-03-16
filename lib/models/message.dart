enum MessageRole { user, assistant, system }

class Message {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isComplete;

  const Message({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isComplete = true,
  });

  Message copyWith({String? content, bool? isComplete}) {
    return Message(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}
