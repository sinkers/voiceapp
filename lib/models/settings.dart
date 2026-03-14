class OpenClawInstance {
  final String id;
  final String name;
  final String baseUrl;
  final String token;

  const OpenClawInstance({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.token = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'token': token,
      };

  factory OpenClawInstance.fromJson(Map<String, dynamic> json) =>
      OpenClawInstance(
        id: json['id'] as String,
        name: json['name'] as String,
        baseUrl: json['baseUrl'] as String,
        token: (json['token'] as String?) ?? '',
      );

  OpenClawInstance copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? token,
  }) =>
      OpenClawInstance(
        id: id ?? this.id,
        name: name ?? this.name,
        baseUrl: baseUrl ?? this.baseUrl,
        token: token ?? this.token,
      );
}

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
  final List<OpenClawInstance> openclawInstances;
  final String? selectedInstanceId;
  final String? selectedAgentId;

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
    this.openclawInstances = const [],
    this.selectedInstanceId,
    this.selectedAgentId,
  });

  String get activeModelName =>
      backend == LLMBackend.claude ? claudeModelName : openaiModelName;

  OpenClawInstance? get selectedInstance {
    if (selectedInstanceId == null) return null;
    final matches = openclawInstances.where((i) => i.id == selectedInstanceId);
    return matches.isEmpty ? null : matches.first;
  }

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
    List<OpenClawInstance>? openclawInstances,
    String? selectedInstanceId,
    String? selectedAgentId,
    bool clearClaudeApiKey = false,
    bool clearOpenaiApiKey = false,
    bool clearSelectedInstanceId = false,
    bool clearSelectedAgentId = false,
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
      openclawInstances: openclawInstances ?? this.openclawInstances,
      selectedInstanceId: clearSelectedInstanceId
          ? null
          : (selectedInstanceId ?? this.selectedInstanceId),
      selectedAgentId: clearSelectedAgentId
          ? null
          : (selectedAgentId ?? this.selectedAgentId),
    );
  }
}
