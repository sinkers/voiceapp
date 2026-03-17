import 'agent_config.dart';
import 'voice_config.dart';
import 'package:collection/collection.dart';

class Settings {
  final List<AgentConfig> agents;
  final List<VoiceConfig> voices;
  final List<OpenClawServer> openclawServers;
  final String? selectedAgentId;
  final String systemPrompt;

  const Settings({
    this.agents = const [],
    this.voices = const [],
    this.openclawServers = const [],
    this.selectedAgentId,
    this.systemPrompt =
        'You are a helpful voice assistant. Keep your responses concise and conversational, '
            'as they will be spoken aloud. Avoid markdown formatting, bullet points, or numbered lists. '
            'Speak naturally as if in a conversation.',
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
      );
}
