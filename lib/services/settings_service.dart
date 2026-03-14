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

  Future<Settings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final backendIndex = prefs.getInt(_keyBackend) ?? 0;
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
  }
}
