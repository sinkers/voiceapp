import 'agent_config.dart';
import 'elevenlabs_voice.dart';
import 'package:collection/collection.dart';
import 'package:openclaw_client/openclaw_client.dart';

const _defaultElevenLabsVoiceId = '21m00Tcm4TlvDq8ikWAM';
const _defaultElevenLabsSpeed = 1.1;


export 'package:openclaw_client/openclaw_client.dart' show OpenClawInstance;

enum LLMBackend { claude, openaiCompatible }

enum TtsProvider { onDevice, elevenlabs, openai }

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
  final TtsProvider ttsProvider;
  final String? elevenLabsApiKey;
  final ElevenLabsVoice? elevenLabsVoice;
  final String elevenLabsVoiceId;
  final String elevenLabsModelId;
  final String openaiTtsVoice;
  final String openaiTtsModel;

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
    this.ttsProvider = TtsProvider.onDevice,
    this.elevenLabsApiKey,
    this.elevenLabsVoice = ElevenLabsVoice.rachel,
    this.elevenLabsVoiceId = _defaultElevenLabsVoiceId,
    this.elevenLabsModelId = 'eleven_turbo_v2_5',
    this.openaiTtsVoice = 'alloy',
    this.openaiTtsModel = 'tts-1',
  });

  String get activeModelName =>
      backend == LLMBackend.claude ? claudeModelName : openaiModelName;

  OpenClawInstance? get selectedInstance =>
      openclawInstances.firstWhereOrNull((i) => i.id == selectedInstanceId);

  /// Flat list of all agents: one per agent per OpenClaw instance + direct model agents.
  List<AgentConfig> get allAgents {
    return [
      ...openclawInstances.expand(
        (instance) => instance.agentIds.map(
          (agentId) => OpenClawAgentConfig(
            instance: instance,
            agentId: agentId,
          ),
        ),
      ),
      DirectModelAgentConfig(
        backend: LLMBackend.claude,
        modelName: claudeModelName,
      ),
      DirectModelAgentConfig(
        backend: LLMBackend.openaiCompatible,
        modelName: openaiModelName,
      ),
    ];
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
    TtsProvider? ttsProvider,
    String? elevenLabsApiKey,
    ElevenLabsVoice? elevenLabsVoice,
    String? elevenLabsVoiceId,
    String? elevenLabsModelId,
    String? openaiTtsVoice,
    String? openaiTtsModel,
    bool clearClaudeApiKey = false,
    bool clearOpenaiApiKey = false,
    bool clearSelectedInstanceId = false,
    bool clearSelectedAgentId = false,
    bool clearElevenLabsApiKey = false,
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
      ttsProvider: ttsProvider ?? this.ttsProvider,
      elevenLabsApiKey: clearElevenLabsApiKey
          ? null
          : (elevenLabsApiKey ?? this.elevenLabsApiKey),
      elevenLabsVoice: elevenLabsVoice ?? this.elevenLabsVoice,
      elevenLabsVoiceId: elevenLabsVoiceId ?? this.elevenLabsVoiceId,
      elevenLabsModelId: elevenLabsModelId ?? this.elevenLabsModelId,
      openaiTtsVoice: openaiTtsVoice ?? this.openaiTtsVoice,
      openaiTtsModel: openaiTtsModel ?? this.openaiTtsModel,
    );
  }
}
