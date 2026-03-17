import 'agent_config.dart';
import 'voice_config.dart';
import 'elevenlabs_voice.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

const bool kDefaultConversationalMode = false;
const double kDefaultPauseDuration = 1.5;

class OpenClawInstance {
  final String id;
  final String name;
  final String baseUrl;
  final String token;
  final String sessionId;
  final ElevenLabsVoice elevenLabsVoice;
  final double elevenLabsSpeed;
  final List<String> agentIds;
  final bool allowBadCertificate;

  const OpenClawInstance({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.token = '',
    required this.sessionId,
    this.elevenLabsVoice = ElevenLabsVoice.rachel,
    this.elevenLabsSpeed = 1.1,
    this.agentIds = const ['main'],
    this.allowBadCertificate = false,
  });

  // Token is stored in secure storage, not in JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        // token excluded - stored in flutter_secure_storage
        'sessionId': sessionId,
        'elevenLabsVoiceId': elevenLabsVoice.voiceId,
        'elevenLabsSpeed': elevenLabsSpeed,
        'agentIds': agentIds,
        'allowBadCertificate': allowBadCertificate,
      };

  factory OpenClawInstance.fromJson(Map<String, dynamic> json) =>
      OpenClawInstance(
        id: json['id'] as String,
        name: json['name'] as String,
        baseUrl: json['baseUrl'] as String,
        token: (json['token'] as String?) ?? '',
        sessionId: json['sessionId'] as String? ?? _uuid.v4(),
        elevenLabsVoice: ElevenLabsVoice.fromVoiceId(
              json['elevenLabsVoiceId'] as String? ?? '',
            ) ??
            ElevenLabsVoice.rachel,
        elevenLabsSpeed: (json['elevenLabsSpeed'] as num?)?.toDouble() ?? 1.1,
        agentIds: (json['agentIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const ['main'],
        allowBadCertificate: (json['allowBadCertificate'] as bool?) ?? false,
      );

  OpenClawInstance copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? token,
    String? sessionId,
    ElevenLabsVoice? elevenLabsVoice,
    double? elevenLabsSpeed,
    List<String>? agentIds,
    bool? allowBadCertificate,
  }) =>
      OpenClawInstance(
        id: id ?? this.id,
        name: name ?? this.name,
        baseUrl: baseUrl ?? this.baseUrl,
        token: token ?? this.token,
        sessionId: sessionId ?? this.sessionId,
        elevenLabsVoice: elevenLabsVoice ?? this.elevenLabsVoice,
        elevenLabsSpeed: elevenLabsSpeed ?? this.elevenLabsSpeed,
        agentIds: agentIds ?? this.agentIds,
        allowBadCertificate: allowBadCertificate ?? this.allowBadCertificate,
      );
}

enum LLMBackend { claude, openaiCompatible }

enum TtsProvider { onDevice, elevenlabs, openai }

class Settings {
  final List<AgentConfig> agents;
  final List<VoiceConfig> voices;
  final List<OpenClawServer> openclawServers;
  final String? selectedAgentId;
  final String systemPrompt;
  final bool conversationalMode;
  final double pauseDuration;

  const Settings({
    this.agents = const [],
    this.voices = const [],
    this.openclawServers = const [],
    this.selectedAgentId,
    this.systemPrompt =
        'You are a helpful voice assistant. Keep your responses concise and conversational, '
            'as they will be spoken aloud. Avoid markdown formatting, bullet points, or numbered lists. '
            'Speak naturally as if in a conversation.',
    this.conversationalMode = kDefaultConversationalMode,
    this.pauseDuration = kDefaultPauseDuration,
  });

  AgentConfig? get selectedAgent =>
      agents.firstWhereOrNull((a) => a.id == selectedAgentId);

  VoiceConfig? getVoiceById(String voiceId) =>
      voices.firstWhereOrNull((v) => v.id == voiceId);

  OpenClawServer? getServerById(String serverId) =>
      openclawServers.firstWhereOrNull((s) => s.id == serverId);

  Settings copyWith({
    List<AgentConfig>? agents,
    List<VoiceConfig>? voices,
    List<OpenClawServer>? openclawServers,
    String? selectedAgentId,
    String? systemPrompt,
    bool? conversationalMode,
    double? pauseDuration,
    bool clearSelectedAgentId = false,
  }) =>
      Settings(
        agents: agents ?? this.agents,
        voices: voices ?? this.voices,
        openclawServers: openclawServers ?? this.openclawServers,
        selectedAgentId: clearSelectedAgentId
            ? null
            : (selectedAgentId ?? this.selectedAgentId),
        systemPrompt: systemPrompt ?? this.systemPrompt,
        conversationalMode: conversationalMode ?? this.conversationalMode,
        pauseDuration: pauseDuration ?? this.pauseDuration,
      );
}
