import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';

class SettingsService {
  // Secure storage keys (sensitive data)
  static const _secureKeyClaudeApiKey = 'claude_api_key';
  static const _secureKeyOpenaiApiKey = 'openai_api_key';
  static const _secureKeyElevenLabsApiKey = 'elevenlabs_api_key';

  // SharedPreferences keys (non-sensitive data)
  static const _keyBackend = 'backend';
  static const _keyOpenaiBaseUrl = 'openai_base_url';
  static const _keyClaudeModelName = 'claude_model_name';
  static const _keyOpenaiModelName = 'openai_model_name';
  static const _keySystemPrompt = 'system_prompt';
  static const _keyTtsRate = 'tts_rate';
  static const _keyTtsPitch = 'tts_pitch';
  static const _keyOpenclawInstances = 'openclaw_instances';
  static const _keySelectedInstanceId = 'selected_instance_id';
  static const _keySelectedAgentId = 'selected_agent_id';
  static const _keyTtsProvider = 'tts_provider';
  static const _keyElevenLabsVoiceId = 'elevenlabs_voice_id';
  static const _keyElevenLabsModelId = 'elevenlabs_model_id';
  static const _keyOpenaiTtsVoice = 'openai_tts_voice';
  static const _keyOpenaiTtsModel = 'openai_tts_model';
  static const _keyConversationalMode = 'conversational_mode';
  static const _keyPauseDuration = 'pause_duration';

  static String _openClawTokenKey(String instanceId) =>
      'openclaw_token_$instanceId';

  final _secureStorage = const FlutterSecureStorage();

  Future<Settings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final backendIndex = prefs.getInt(_keyBackend) ?? 0;

    final instancesJson = prefs.getString(_keyOpenclawInstances);
    final openclawInstancesWithoutTokens = instancesJson != null
        ? (jsonDecode(instancesJson) as List)
            .whereType<Map<String, dynamic>>()
            .map(OpenClawInstance.fromJson)
            .toList()
        : <OpenClawInstance>[];

    // Load tokens from secure storage for each instance (parallel reads)
    final openclawInstances = await Future.wait(
      openclawInstancesWithoutTokens.map((instance) async {
        final token =
            await _secureStorage.read(key: _openClawTokenKey(instance.id)) ??
                '';
        return instance.copyWith(token: token);
      }),
    );

    final ttsProviderIndex = prefs.getInt(_keyTtsProvider) ?? 0;

    return Settings(
      claudeApiKey: await _secureStorage.read(key: _secureKeyClaudeApiKey),
      openaiApiKey: await _secureStorage.read(key: _secureKeyOpenaiApiKey),
      backend: LLMBackend.values[backendIndex],
      openaiBaseUrl:
          prefs.getString(_keyOpenaiBaseUrl) ?? 'https://api.openai.com/v1',
      claudeModelName:
          prefs.getString(_keyClaudeModelName) ?? 'claude-opus-4-6',
      openaiModelName: prefs.getString(_keyOpenaiModelName) ?? 'gpt-4o',
      systemPrompt: prefs.getString(_keySystemPrompt) ??
          'You are a helpful voice assistant. Keep your responses concise and conversational, '
              'as they will be spoken aloud. Avoid markdown formatting, bullet points, or numbered lists. '
              'Speak naturally as if in a conversation.',
      ttsRate: prefs.getDouble(_keyTtsRate) ?? 0.5,
      ttsPitch: prefs.getDouble(_keyTtsPitch) ?? 1.0,
      openclawInstances: openclawInstances,
      selectedInstanceId: prefs.getString(_keySelectedInstanceId),
      selectedAgentId: prefs.getString(_keySelectedAgentId),
      ttsProvider: TtsProvider.values[ttsProviderIndex],
      elevenLabsApiKey: await _secureStorage.read(
        key: _secureKeyElevenLabsApiKey,
      ),
      elevenLabsVoiceId:
          prefs.getString(_keyElevenLabsVoiceId) ?? '21m00Tcm4TlvDq8ikWAM',
      elevenLabsModelId:
          prefs.getString(_keyElevenLabsModelId) ?? 'eleven_turbo_v2_5',
      openaiTtsVoice: prefs.getString(_keyOpenaiTtsVoice) ?? 'alloy',
      openaiTtsModel: prefs.getString(_keyOpenaiTtsModel) ?? 'tts-1',
      conversationalMode: prefs.getBool(_keyConversationalMode) ?? false,
      pauseDuration: prefs.getDouble(_keyPauseDuration) ?? 1.5,
    );
  }

  Future<void> save(Settings settings) async {
    final prefs = await SharedPreferences.getInstance();

    // Save sensitive keys to secure storage
    if (settings.claudeApiKey != null) {
      await _secureStorage.write(
        key: _secureKeyClaudeApiKey,
        value: settings.claudeApiKey,
      );
    } else {
      await _secureStorage.delete(key: _secureKeyClaudeApiKey);
    }
    if (settings.openaiApiKey != null) {
      await _secureStorage.write(
        key: _secureKeyOpenaiApiKey,
        value: settings.openaiApiKey,
      );
    } else {
      await _secureStorage.delete(key: _secureKeyOpenaiApiKey);
    }
    if (settings.elevenLabsApiKey != null) {
      await _secureStorage.write(
        key: _secureKeyElevenLabsApiKey,
        value: settings.elevenLabsApiKey,
      );
    } else {
      await _secureStorage.delete(key: _secureKeyElevenLabsApiKey);
    }

    // Save OpenClaw instance tokens to secure storage (parallel writes)
    await Future.wait(
      settings.openclawInstances.map((instance) {
        if (instance.token.isNotEmpty) {
          return _secureStorage.write(
            key: _openClawTokenKey(instance.id),
            value: instance.token,
          );
        } else {
          return _secureStorage.delete(key: _openClawTokenKey(instance.id));
        }
      }),
    );

    // Save non-sensitive settings to SharedPreferences
    await prefs.setInt(_keyBackend, settings.backend.index);
    await prefs.setString(_keyOpenaiBaseUrl, settings.openaiBaseUrl);
    await prefs.setString(_keyClaudeModelName, settings.claudeModelName);
    await prefs.setString(_keyOpenaiModelName, settings.openaiModelName);
    await prefs.setString(_keySystemPrompt, settings.systemPrompt);
    await prefs.setDouble(_keyTtsRate, settings.ttsRate);
    await prefs.setDouble(_keyTtsPitch, settings.ttsPitch);
    await prefs.setString(
      _keyOpenclawInstances,
      jsonEncode(settings.openclawInstances.map((i) => i.toJson()).toList()),
    );
    if (settings.selectedInstanceId != null) {
      await prefs.setString(
        _keySelectedInstanceId,
        settings.selectedInstanceId!,
      );
    } else {
      await prefs.remove(_keySelectedInstanceId);
    }
    if (settings.selectedAgentId != null) {
      await prefs.setString(_keySelectedAgentId, settings.selectedAgentId!);
    } else {
      await prefs.remove(_keySelectedAgentId);
    }
    await prefs.setInt(_keyTtsProvider, settings.ttsProvider.index);
    await prefs.setString(_keyElevenLabsVoiceId, settings.elevenLabsVoiceId);
    await prefs.setString(_keyElevenLabsModelId, settings.elevenLabsModelId);
    await prefs.setString(_keyOpenaiTtsVoice, settings.openaiTtsVoice);
    await prefs.setString(_keyOpenaiTtsModel, settings.openaiTtsModel);
    await prefs.setBool(_keyConversationalMode, settings.conversationalMode);
    await prefs.setDouble(_keyPauseDuration, settings.pauseDuration);
  }
}
