import 'package:http/http.dart' as http;
import 'package:openai_dart/openai_dart.dart';
import '../models/message.dart' as app;
import 'http_client_factory.dart';
import 'llm_service.dart';

class OpenAIService implements LLMService {
  final String apiKey;
  final String baseUrl;
  final String model;
  final Map<String, String>? customHeaders;
  final bool allowBadCertificate;
  late final OpenAIClient _client;
  late final http.Client _httpClient;

  OpenAIService({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    this.customHeaders,
    this.allowBadCertificate = false,
  }) {
    final cleanUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    _httpClient = buildHttpClient(allowBadCertificate: allowBadCertificate);
    _client = OpenAIClient(
      apiKey: apiKey,
      baseUrl: cleanUrl,
      headers: customHeaders,
      client: _httpClient,
    );
  }

  @override
  Stream<String> streamResponse(
    List<app.Message> history,
    String systemPrompt,
  ) async* {
    final messages = <ChatCompletionMessage>[
      if (systemPrompt.isNotEmpty)
        ChatCompletionMessage.system(content: systemPrompt),
      ...history.where((m) => m.role != app.MessageRole.system).map(
            (m) => m.role == app.MessageRole.user
                ? ChatCompletionMessage.user(
                    content: ChatCompletionUserMessageContent.string(m.content),
                  )
                : ChatCompletionMessage.assistant(content: m.content),
          ),
    ];

    final stream = _client.createChatCompletionStream(
      request: CreateChatCompletionRequest(
        model: ChatCompletionModel.modelId(model),
        messages: messages,
        maxTokens: 4096,
      ),
    );

    await for (final chunk in stream) {
      final delta = chunk.choices.firstOrNull?.delta.content;
      if (delta != null) {
        yield delta;
      }
    }
  }

  @override
  void dispose() {
    _client.endSession();
    _httpClient.close();
  }
}
