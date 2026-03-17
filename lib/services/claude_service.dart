import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';
import '../models/message.dart' as app;
import 'llm_service.dart';

class ClaudeService implements LLMService {
  final String apiKey;
  final String model;
  late final AnthropicClient _client;

  ClaudeService({required this.apiKey, required this.model}) {
    _client = AnthropicClient.withApiKey(apiKey);
  }

  @override
  Stream<String> streamResponse(
    List<app.Message> history,
    String systemPrompt,
  ) async* {
    final messages = history
        .where((m) => m.role != app.MessageRole.system)
        .map(
          (m) => m.role == app.MessageRole.user
              ? InputMessage.user(m.content)
              : InputMessage.assistant(m.content),
        )
        .toList();

    final stream = _client.messages.createStream(
      MessageCreateRequest(
        model: model,
        maxTokens: 4096,
        system: systemPrompt.isNotEmpty
            ? SystemPrompt.text(systemPrompt)
            : null,
        messages: messages,
      ),
    );

    yield* stream.textDeltas();
  }

  @override
  void dispose() {
    _client.close();
  }
}
