import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';

class SettingsService {
  static const _keyClaudeApiKey = 'claude_api_key';
  static const _keyOpenaiApiKey = 'openai_api_key';
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
  static const _keyElevenLabsApiKey = 'elevenlabs_api_key';
  static const _keyElevenLabsVoiceId = 'elevenlabs_voice_id';
  static const _keyElevenLabsModelId = 'elevenlabs_model_id';
  static const _keyOpenaiTtsVoice = 'openai_tts_voice';
  static const _keyOpenaiTtsModel = 'openai_tts_model';

  Future<Settings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final backendIndex = prefs.getInt(_keyBackend) ?? 0;

    final instancesJson = prefs.getString(_keyOpenclawInstances);
    final openclawInstances = instancesJson != null
        ? (jsonDecode(instancesJson) as List)
            .whereType<Map<String, dynamic>>()
            .map(OpenClawInstance.fromJson)
            .toList()
        : <OpenClawInstance>[];

    final ttsProviderIndex = prefs.getInt(_keyTtsProvider) ?? 0;

    return Settings(
      claudeApiKey: prefs.getString(_keyClaudeApiKey),
      openaiApiKey: prefs.getString(_keyOpenaiApiKey),
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
      elevenLabsApiKey: prefs.getString(_keyElevenLabsApiKey),
      elevenLabsVoiceId:
          prefs.getString(_keyElevenLabsVoiceId) ?? '21m00Tcm4TlvDq8ikWAM',
      elevenLabsModelId:
          prefs.getString(_keyElevenLabsModelId) ?? 'eleven_turbo_v2_5',
      openaiTtsVoice: prefs.getString(_keyOpenaiTtsVoice) ?? 'alloy',
      openaiTtsModel: prefs.getString(_keyOpenaiTtsModel) ?? 'tts-1',
    );
  }

  Future<void> save(Settings settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (settings.claudeApiKey != null) {
      await prefs.setString(_keyClaudeApiKey, settings.claudeApiKey!);
    } else {
      await prefs.remove(_keyClaudeApiKey);
    }
    if (settings.openaiApiKey != null) {
      await prefs.setString(_keyOpenaiApiKey, settings.openaiApiKey!);
    } else {
      await prefs.remove(_keyOpenaiApiKey);
    }
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
          _keySelectedInstanceId, settings.selectedInstanceId!);
    } else {
      await prefs.remove(_keySelectedInstanceId);
    }
    if (settings.selectedAgentId != null) {
      await prefs.setString(_keySelectedAgentId, settings.selectedAgentId!);
    } else {
      await prefs.remove(_keySelectedAgentId);
    }
    await prefs.setInt(_keyTtsProvider, settings.ttsProvider.index);
    if (settings.elevenLabsApiKey != null) {
      await prefs.setString(_keyElevenLabsApiKey, settings.elevenLabsApiKey!);
    } else {
      await prefs.remove(_keyElevenLabsApiKey);
    }
    await prefs.setString(_keyElevenLabsVoiceId, settings.elevenLabsVoiceId);
    await prefs.setString(_keyElevenLabsModelId, settings.elevenLabsModelId);
    await prefs.setString(_keyOpenaiTtsVoice, settings.openaiTtsVoice);
    await prefs.setString(_keyOpenaiTtsModel, settings.openaiTtsModel);
  }
}
