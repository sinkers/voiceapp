/// A chat message to send to an OpenClaw agent.
class OpenClawMessage {
  final String role;
  final String content;

  const OpenClawMessage({required this.role, required this.content});

  factory OpenClawMessage.user(String content) =>
      OpenClawMessage(role: 'user', content: content);

  factory OpenClawMessage.assistant(String content) =>
      OpenClawMessage(role: 'assistant', content: content);

  factory OpenClawMessage.system(String content) =>
      OpenClawMessage(role: 'system', content: content);

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}
