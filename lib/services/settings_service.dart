import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agent_config.dart';
import '../models/settings.dart';
import '../models/voice_config.dart';
import '../models/elevenlabs_voice.dart';

class SettingsService {
  // New keys for refactored settings
  static const _keyAgents = 'agents_v2';
  static const _keyVoices = 'voices_v2';
  static const _keyOpenClawServers = 'openclaw_servers_v2';
  static const _keySelectedAgentId = 'selected_agent_id_v2';
  static const _keySystemPrompt = 'system_prompt';
  static const _keyMigrated = 'migrated_to_v2';

  // Old keys (for migration)
  static const _keyBackend = 'backend';
  static const _keyClaudeModelName = 'claude_model_name';
  static const _keyOpenaiModelName = 'openai_model_name';
  static const _keyOpenaiBaseUrl = 'openai_base_url';
  static const _keyOpenclawInstances = 'openclaw_instances';
  static const _keySelectedInstanceId = 'selected_instance_id';
  static const _keySelectedAgentIdOld = 'selected_agent_id';
  static const _keyTtsProvider = 'tts_provider';
  static const _keyTtsRate = 'tts_rate';
  static const _keyTtsPitch = 'tts_pitch';
  static const _keyElevenLabsVoiceId = 'elevenlabs_voice_id';
  static const _keyElevenLabsModelId = 'elevenlabs_model_id';
  static const _keyOpenaiTtsVoice = 'openai_tts_voice';
  static const _keyOpenaiTtsModel = 'openai_tts_model';
  static const _keyDefaultConfigsLoaded = 'default_configs_loaded';

  // Secure storage keys
  static const _secureKeyClaudeApiKey = 'claude_api_key';
  static const _secureKeyOpenaiApiKey = 'openai_api_key';
  static const _secureKeyElevenLabsApiKey = 'elevenlabs_api_key';

  static String _agentApiKeyKey(String agentId) => 'agent_api_key_$agentId';
  static String _voiceApiKeyKey(String voiceId) => 'voice_api_key_$voiceId';
  static String _serverTokenKey(String serverId) => 'server_token_$serverId';
  static String _openClawTokenKeyOld(String instanceId) =>
      'openclaw_token_$instanceId';

  final _secureStorage = const FlutterSecureStorage();

  /// Number of default configs loaded on last first launch (used for banner)
  int? lastLoadedConfigCount;

  Future<Settings> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Migrate old settings if needed
    if (prefs.getBool(_keyMigrated) != true) {
      await _migrateFromOldSettings(prefs);
    }

    // Load default voices on first launch if needed
    lastLoadedConfigCount = await _loadDefaultVoicesIfNeeded(prefs);

    // Load agents
    final agentsJson = prefs.getString(_keyAgents);
    final agentsWithoutApiKeys = agentsJson != null
        ? (jsonDecode(agentsJson) as List)
            .whereType<Map<String, dynamic>>()
            .map(AgentConfig.fromJson)
            .toList()
        : <AgentConfig>[];

    // Load API keys from secure storage for each agent
    final agents = await Future.wait(
      agentsWithoutApiKeys.map((agent) async {
        if (agent.apiKey != null) {
          // Already has API key from JSON (shouldn't happen but handle it)
          return agent;
        }
        final apiKey =
            await _secureStorage.read(key: _agentApiKeyKey(agent.id));
        return apiKey != null
            ? agent.copyWith(apiKey: apiKey)
            : agent;
      }),
    );

    // Load voices
    final voicesJson = prefs.getString(_keyVoices);
    final voicesWithoutApiKeys = voicesJson != null
        ? (jsonDecode(voicesJson) as List)
            .whereType<Map<String, dynamic>>()
            .map(VoiceConfig.fromJson)
            .toList()
        : <VoiceConfig>[];

    // Load API keys from secure storage for each voice
    final voices = await Future.wait(
      voicesWithoutApiKeys.map((voice) async {
        if (voice.apiKey != null) {
          // Already has API key from JSON
          return voice;
        }
        final apiKey =
            await _secureStorage.read(key: _voiceApiKeyKey(voice.id));
        return apiKey != null
            ? voice.copyWith(apiKey: apiKey)
            : voice;
      }),
    );

    // Load OpenClaw servers
    final serversJson = prefs.getString(_keyOpenClawServers);
    final serversWithoutTokens = serversJson != null
        ? (jsonDecode(serversJson) as List)
            .whereType<Map<String, dynamic>>()
            .map(OpenClawServer.fromJson)
            .toList()
        : <OpenClawServer>[];

    // Load tokens from secure storage for each server
    final servers = await Future.wait(
      serversWithoutTokens.map((server) async {
        final token =
            await _secureStorage.read(key: _serverTokenKey(server.id));
        return token != null ? server.copyWith(token: token) : server;
      }),
    );

    return Settings(
      agents: agents,
      voices: voices,
      openclawServers: servers,
      selectedAgentId: prefs.getString(_keySelectedAgentId),
      systemPrompt: prefs.getString(_keySystemPrompt) ??
          'You are a helpful voice assistant. Keep your responses concise and conversational, '
              'as they will be spoken aloud. Avoid markdown formatting, bullet points, or numbered lists. '
              'Speak naturally as if in a conversation.',
    );
  }

  Future<void> save(Settings settings) async {
    final prefs = await SharedPreferences.getInstance();

    // Save agents (without API keys)
    final agentsJson = jsonEncode(
      settings.agents
          .map((a) => a.copyWith(clearApiKey: true).toJson())
          .toList(),
    );
    await prefs.setString(_keyAgents, agentsJson);

    // Save agent API keys to secure storage
    await Future.wait(
      settings.agents.where((a) => a.apiKey != null).map(
            (a) => _secureStorage.write(
              key: _agentApiKeyKey(a.id),
              value: a.apiKey!,
            ),
          ),
    );

    // Save voices (without API keys)
    final voicesJson = jsonEncode(
      settings.voices
          .map((v) => v.copyWith(clearApiKey: true).toJson())
          .toList(),
    );
    await prefs.setString(_keyVoices, voicesJson);

    // Save voice API keys to secure storage
    await Future.wait(
      settings.voices.where((v) => v.apiKey != null).map(
            (v) => _secureStorage.write(
              key: _voiceApiKeyKey(v.id),
              value: v.apiKey!,
            ),
          ),
    );

    // Save OpenClaw servers (without tokens)
    final serversJson = jsonEncode(
      settings.openclawServers
          .map((s) => s.copyWith(clearToken: true).toJson())
          .toList(),
    );
    await prefs.setString(_keyOpenClawServers, serversJson);

    // Save server tokens to secure storage
    await Future.wait(
      settings.openclawServers.where((s) => s.token != null).map(
            (s) => _secureStorage.write(
              key: _serverTokenKey(s.id),
              value: s.token!,
            ),
          ),
    );

    // Save other settings
    if (settings.selectedAgentId != null) {
      await prefs.setString(_keySelectedAgentId, settings.selectedAgentId!);
    } else {
      await prefs.remove(_keySelectedAgentId);
    }
    await prefs.setString(_keySystemPrompt, settings.systemPrompt);
  }

  /// Migrates old settings structure to new agents + voices model
  Future<void> _migrateFromOldSettings(SharedPreferences prefs) async {
    // Mark as migrated upfront
    await prefs.setBool(_keyMigrated, true);

    final List<AgentConfig> agents = [];
    final List<VoiceConfig> voices = [];
    final List<OpenClawServer> servers = [];

    // 1. Create system voice
    final ttsRate = prefs.getDouble(_keyTtsRate) ?? 0.5;
    final ttsPitch = prefs.getDouble(_keyTtsPitch) ?? 1.0;
    final systemVoice = VoiceConfig.system(rate: ttsRate, pitch: ttsPitch);
    voices.add(systemVoice);

    // 2. Migrate TTS provider to voices
    final ttsProviderIndex = prefs.getInt(_keyTtsProvider) ?? 0;
    String defaultVoiceId = systemVoice.id;

    if (ttsProviderIndex == 1) {
      // ElevenLabs
      final elevenLabsApiKey = await _secureStorage.read(
        key: _secureKeyElevenLabsApiKey,
      );
      final elevenLabsVoiceId =
          prefs.getString(_keyElevenLabsVoiceId) ?? '21m00Tcm4TlvDq8ikWAM';
      final elevenLabsModelId =
          prefs.getString(_keyElevenLabsModelId) ?? 'eleven_turbo_v2_5';

      final elevenLabsVoice = VoiceConfig.elevenlabs(
        name: 'ElevenLabs',
        voiceId: elevenLabsVoiceId,
        apiKey: elevenLabsApiKey,
        modelId: elevenLabsModelId,
      );
      voices.add(elevenLabsVoice);
      defaultVoiceId = elevenLabsVoice.id;
    } else if (ttsProviderIndex == 2) {
      // OpenAI TTS
      final openaiApiKey = await _secureStorage.read(
        key: _secureKeyOpenaiApiKey,
      );
      final openaiTtsVoice = prefs.getString(_keyOpenaiTtsVoice) ?? 'alloy';
      final openaiTtsModel = prefs.getString(_keyOpenaiTtsModel) ?? 'tts-1';

      final openaiVoice = VoiceConfig.openai(
        name: 'OpenAI TTS',
        voiceId: openaiTtsVoice,
        apiKey: openaiApiKey,
        modelId: openaiTtsModel,
      );
      voices.add(openaiVoice);
      defaultVoiceId = openaiVoice.id;
    }

    // 3. Migrate backend to agents
    final backendIndex = prefs.getInt(_keyBackend) ?? 0;
    final claudeApiKey = await _secureStorage.read(
      key: _secureKeyClaudeApiKey,
    );
    final openaiApiKey = await _secureStorage.read(
      key: _secureKeyOpenaiApiKey,
    );

    if (backendIndex == 0 && claudeApiKey != null) {
      // Claude backend
      final claudeModelName =
          prefs.getString(_keyClaudeModelName) ?? 'claude-opus-4-6';
      final claudeAgent = AgentConfig.claude(
        name: 'Claude',
        apiKey: claudeApiKey,
        model: claudeModelName,
        voiceId: defaultVoiceId,
      );
      agents.add(claudeAgent);
    } else if (backendIndex == 1 && openaiApiKey != null) {
      // OpenAI backend
      final openaiModelName = prefs.getString(_keyOpenaiModelName) ?? 'gpt-4o';
      final openaiBaseUrl =
          prefs.getString(_keyOpenaiBaseUrl) ?? 'https://api.openai.com/v1';
      final openaiAgent = AgentConfig.openai(
        name: 'OpenAI',
        apiKey: openaiApiKey,
        model: openaiModelName,
        baseUrl: openaiBaseUrl,
        voiceId: defaultVoiceId,
      );
      agents.add(openaiAgent);
    }

    // 4. Migrate OpenClaw instances to servers + agents
    final instancesJson = prefs.getString(_keyOpenclawInstances);
    if (instancesJson != null) {
      final oldInstances = (jsonDecode(instancesJson) as List)
          .whereType<Map<String, dynamic>>();

      for (final instanceJson in oldInstances) {
        final instanceId = instanceJson['id'] as String;
        final instanceName = instanceJson['name'] as String;
        final baseUrl = instanceJson['baseUrl'] as String;
        final allowBadCertificate =
            (instanceJson['allowBadCertificate'] as bool?) ?? false;

        // Load token from old secure storage key
        final token = await _secureStorage.read(
          key: _openClawTokenKeyOld(instanceId),
        );

        // Create server
        final server = OpenClawServer(
          id: instanceId,
          name: instanceName,
          baseUrl: baseUrl,
          token: token,
          allowBadCertificate: allowBadCertificate,
        );
        servers.add(server);

        // Create voice for this instance (from old per-instance voice settings)
        final elevenLabsVoiceId =
            instanceJson['elevenLabsVoiceId'] as String? ??
                '21m00Tcm4TlvDq8ikWAM';
        final elevenLabsApiKey = await _secureStorage.read(
          key: _secureKeyElevenLabsApiKey,
        );

        // Find matching ElevenLabsVoice enum
        final elevenLabsVoice =
            ElevenLabsVoice.fromVoiceId(elevenLabsVoiceId);
        final voiceName =
            elevenLabsVoice?.label ?? 'ElevenLabs ($instanceName)';

        final instanceVoice = VoiceConfig.elevenlabs(
          name: voiceName,
          voiceId: elevenLabsVoiceId,
          apiKey: elevenLabsApiKey,
          modelId: 'eleven_turbo_v2_5',
        );
        voices.add(instanceVoice);

        // Create agents for each agentId in this instance
        final agentIds = (instanceJson['agentIds'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            ['main'];

        for (final agentId in agentIds) {
          final agent = AgentConfig.openclaw(
            name: '$instanceName / $agentId',
            serverId: server.id,
            agentName: agentId,
            voiceId: instanceVoice.id,
          );
          agents.add(agent);
        }
      }
    }

    // 5. Determine selected agent
    String? selectedAgentId;
    final selectedInstanceId = prefs.getString(_keySelectedInstanceId);
    final selectedOldAgentId = prefs.getString(_keySelectedAgentIdOld);

    if (selectedInstanceId != null && selectedOldAgentId != null) {
      // Try to find matching OpenClaw agent
      final matchingAgent = agents.firstWhereOrNull(
        (a) =>
            a.type == AgentType.openclaw &&
            a.serverId == selectedInstanceId &&
            a.agentName == selectedOldAgentId,
      );
      selectedAgentId = matchingAgent?.id;
    } else if (agents.isNotEmpty) {
      // Select first agent
      selectedAgentId = agents.first.id;
    }

    // 6. Save migrated settings
    final migratedSettings = Settings(
      agents: agents,
      voices: voices,
      openclawServers: servers,
      selectedAgentId: selectedAgentId,
      systemPrompt: prefs.getString(_keySystemPrompt) ??
          'You are a helpful voice assistant. Keep your responses concise and conversational, '
              'as they will be spoken aloud. Avoid markdown formatting, bullet points, or numbered lists. '
              'Speak naturally as if in a conversation.',
    );

    await save(migratedSettings);
  }

  /// Loads default voice providers on first launch if voices list is empty
  Future<int> _loadDefaultVoicesIfNeeded(SharedPreferences prefs) async {
    // Check if already loaded
    if (prefs.getBool(_keyDefaultConfigsLoaded) == true) {
      return 0;
    }

    await prefs.setBool(_keyDefaultConfigsLoaded, true);

    // Check if voices already exist
    final existingVoices = prefs.getString(_keyVoices);
    if (existingVoices != null) {
      return 0;
    }

    // Load default voices
    final voices = <VoiceConfig>[
      VoiceConfig.system(),
      VoiceConfig.elevenlabs(
        name: 'Rachel',
        voiceId: ElevenLabsVoice.rachel.voiceId,
      ),
      VoiceConfig.elevenlabs(
        name: 'Liam',
        voiceId: ElevenLabsVoice.liam.voiceId,
      ),
      VoiceConfig.elevenlabs(
        name: 'Charlotte',
        voiceId: ElevenLabsVoice.charlotte.voiceId,
      ),
      VoiceConfig.elevenlabs(
        name: 'Charlie',
        voiceId: ElevenLabsVoice.charlie.voiceId,
      ),
    ];

    // Try to load ElevenLabs API key from asset
    try {
      final jsonString =
          await rootBundle.loadString('assets/default_configs.json');
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final elevenLabsApiKey = json['elevenlabs_api_key'] as String?;

      if (elevenLabsApiKey != null && elevenLabsApiKey.isNotEmpty) {
        // Add API key to all ElevenLabs voices
        final updatedVoices = voices.map((v) {
          if (v.provider == VoiceProvider.elevenlabs) {
            return v.copyWith(apiKey: elevenLabsApiKey);
          }
          return v;
        }).toList();

        final voicesJson = jsonEncode(
          updatedVoices
              .map((v) => v.copyWith(clearApiKey: true).toJson())
              .toList(),
        );
        await prefs.setString(_keyVoices, voicesJson);

        // Save API keys to secure storage
        await Future.wait(
          updatedVoices
              .where((v) => v.apiKey != null)
              .map(
                (v) => _secureStorage.write(
                  key: _voiceApiKeyKey(v.id),
                  value: v.apiKey!,
                ),
              ),
        );

        return updatedVoices.length;
      }
    } catch (e) {
      // Asset not found - continue with voices without API keys
    }

    // Save default voices (without API keys)
    final voicesJson = jsonEncode(
      voices.map((v) => v.toJson()).toList(),
    );
    await prefs.setString(_keyVoices, voicesJson);

    return voices.length;
  }
}
