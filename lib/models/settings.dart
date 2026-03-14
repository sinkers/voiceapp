enum LLMBackend { claude, openaiCompatible }

class Settings {
  final String? claudeApiKey;
  final String? openaiApiKey;
  final LLMBackend backend;
  final String openaiBaseUrl;
  final String claudeModelName;
  final String openaiModelName;
  final String systemPrompt;
  final double ttsRate;
  final double ttsPitch;

  const Settings({
    this.claudeApiKey,
    this.openaiApiKey,
    this.backend = LLMBackend.claude,
    this.openaiBaseUrl = 'https://api.openai.com/v1',
    this.claudeModelName = 'claude-opus-4-6',
    this.openaiModelName = 'gpt-4o',
    this.systemPrompt =
        'You are a helpful voice assistant. Keep your responses concise and conversational, '
        'as they will be spoken aloud. Avoid markdown formatting, bullet points, or numbered lists. '
        'Speak naturally as if in a conversation.',
    this.ttsRate = 0.5,
    this.ttsPitch = 1.0,
  });

  String get activeModelName =>
      backend == LLMBackend.claude ? claudeModelName : openaiModelName;

  Settings copyWith({
    String? claudeApiKey,
    String? openaiApiKey,
    LLMBackend? backend,
    String? openaiBaseUrl,
    String? claudeModelName,
    String? openaiModelName,
    String? systemPrompt,
    double? ttsRate,
    double? ttsPitch,
    bool clearClaudeApiKey = false,
    bool clearOpenaiApiKey = false,
  }) {
    return Settings(
      claudeApiKey:
          clearClaudeApiKey ? null : (claudeApiKey ?? this.claudeApiKey),
      openaiApiKey:
          clearOpenaiApiKey ? null : (openaiApiKey ?? this.openaiApiKey),
      backend: backend ?? this.backend,
      openaiBaseUrl: openaiBaseUrl ?? this.openaiBaseUrl,
      claudeModelName: claudeModelName ?? this.claudeModelName,
      openaiModelName: openaiModelName ?? this.openaiModelName,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      ttsRate: ttsRate ?? this.ttsRate,
      ttsPitch: ttsPitch ?? this.ttsPitch,
    );
  }
}
