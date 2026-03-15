import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voiceapp/models/settings.dart';
import 'package:voiceapp/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService Serialisation', () {
    late SettingsService service;

    setUp(() {
      service = SettingsService();
      SharedPreferences.setMockInitialValues({});
    });

    test('loads default settings when no data is stored', () async {
      final settings = await service.load();

      expect(settings.backend, LLMBackend.claude);
      expect(settings.openaiBaseUrl, 'https://api.openai.com/v1');
      expect(settings.claudeModelName, 'claude-opus-4-6');
      expect(settings.openaiModelName, 'gpt-4o');
      expect(settings.ttsRate, 0.5);
      expect(settings.ttsPitch, 1.0);
      expect(settings.ttsProvider, TtsProvider.onDevice);
      expect(settings.openclawInstances, isEmpty);
    });

    test('saves and loads Claude API key', () async {
      const settings = Settings(
        claudeApiKey: 'sk-ant-test-key',
        backend: LLMBackend.claude,
      );

      await service.save(settings);
      final loaded = await service.load();

      expect(loaded.claudeApiKey, 'sk-ant-test-key');
      expect(loaded.backend, LLMBackend.claude);
    });

    test('saves and loads OpenAI API key', () async {
      const settings = Settings(
        openaiApiKey: 'sk-test-openai-key',
        backend: LLMBackend.openaiCompatible,
      );

      await service.save(settings);
      final loaded = await service.load();

      expect(loaded.openaiApiKey, 'sk-test-openai-key');
      expect(loaded.backend, LLMBackend.openaiCompatible);
    });

    test('saves and loads backend selection', () async {
      const settings = Settings(backend: LLMBackend.openaiCompatible);

      await service.save(settings);
      final loaded = await service.load();

      expect(loaded.backend, LLMBackend.openaiCompatible);
    });

    test('saves and loads model names', () async {
      const settings = Settings(
        claudeModelName: 'claude-sonnet-4',
        openaiModelName: 'gpt-4-turbo',
      );

      await service.save(settings);
      final loaded = await service.load();

      expect(loaded.claudeModelName, 'claude-sonnet-4');
      expect(loaded.openaiModelName, 'gpt-4-turbo');
    });

    test('saves and loads system prompt', () async {
      const customPrompt = 'You are a test assistant.';
      const settings = Settings(systemPrompt: customPrompt);

      await service.save(settings);
      final loaded = await service.load();

      expect(loaded.systemPrompt, customPrompt);
    });

    test('saves and loads TTS settings', () async {
      const settings = Settings(
        ttsRate: 0.75,
        ttsPitch: 1.2,
        ttsProvider: TtsProvider.elevenlabs,
      );

      await service.save(settings);
      final loaded = await service.load();

      expect(loaded.ttsRate, 0.75);
      expect(loaded.ttsPitch, 1.2);
      expect(loaded.ttsProvider, TtsProvider.elevenlabs);
    });

    test('saves and loads ElevenLabs settings', () async {
      const settings = Settings(
        elevenLabsApiKey: 'test-elevenlabs-key',
        elevenLabsVoiceId: 'test-voice-id',
        elevenLabsModelId: 'test-model-id',
        ttsProvider: TtsProvider.elevenlabs,
      );

      await service.save(settings);
      final loaded = await service.load();

      expect(loaded.elevenLabsApiKey, 'test-elevenlabs-key');
      expect(loaded.elevenLabsVoiceId, 'test-voice-id');
      expect(loaded.elevenLabsModelId, 'test-model-id');
    });

    test('saves and loads OpenAI TTS settings', () async {
      const settings = Settings(
        ttsProvider: TtsProvider.openai,
        openaiTtsVoice: 'nova',
        openaiTtsModel: 'tts-1-hd',
      );

      await service.save(settings);
      final loaded = await service.load();

      expect(loaded.openaiTtsVoice, 'nova');
      expect(loaded.openaiTtsModel, 'tts-1-hd');
    });

    test('saves and loads OpenClaw instances', () async {
      const instance = OpenClawInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'http://localhost:3000/v1',
        token: 'test-token',
      );
      const settings = Settings(
        openclawInstances: [instance],
        selectedInstanceId: 'test-id',
        selectedAgentId: 'main',
      );

      await service.save(settings);
      final loaded = await service.load();

      expect(loaded.openclawInstances.length, 1);
      expect(loaded.openclawInstances.first.id, 'test-id');
      expect(loaded.openclawInstances.first.name, 'Test Instance');
      expect(
          loaded.openclawInstances.first.baseUrl, 'http://localhost:3000/v1');
      expect(loaded.openclawInstances.first.token, 'test-token');
      expect(loaded.selectedInstanceId, 'test-id');
      expect(loaded.selectedAgentId, 'main');
    });

    test('removes API key when set to null', () async {
      // First save with API key
      const settings1 = Settings(claudeApiKey: 'test-key');
      await service.save(settings1);
      var loaded = await service.load();
      expect(loaded.claudeApiKey, 'test-key');

      // Then save with null API key
      const settings2 = Settings(claudeApiKey: null);
      await service.save(settings2);
      loaded = await service.load();
      expect(loaded.claudeApiKey, isNull);
    });

    test('handles multiple OpenClaw instances', () async {
      const instance1 = OpenClawInstance(
        id: 'id-1',
        name: 'Instance 1',
        baseUrl: 'http://localhost:3000/v1',
      );
      const instance2 = OpenClawInstance(
        id: 'id-2',
        name: 'Instance 2',
        baseUrl: 'http://10.0.0.1:8000/v1',
        token: 'token-2',
      );
      const settings = Settings(
        openclawInstances: [instance1, instance2],
        selectedInstanceId: 'id-2',
      );

      await service.save(settings);
      final loaded = await service.load();

      expect(loaded.openclawInstances.length, 2);
      expect(loaded.openclawInstances[0].id, 'id-1');
      expect(loaded.openclawInstances[1].id, 'id-2');
      expect(loaded.selectedInstanceId, 'id-2');
    });

    test('round-trip preserves all settings', () async {
      const original = Settings(
        claudeApiKey: 'claude-key',
        openaiApiKey: 'openai-key',
        backend: LLMBackend.openaiCompatible,
        openaiBaseUrl: 'http://custom:8000/v1',
        claudeModelName: 'claude-custom',
        openaiModelName: 'gpt-custom',
        systemPrompt: 'Custom prompt',
        ttsRate: 0.6,
        ttsPitch: 1.1,
        ttsProvider: TtsProvider.elevenlabs,
        elevenLabsApiKey: 'eleven-key',
        elevenLabsVoiceId: 'voice-123',
        elevenLabsModelId: 'model-456',
        openaiTtsVoice: 'echo',
        openaiTtsModel: 'tts-1-hd',
      );

      await service.save(original);
      final loaded = await service.load();

      expect(loaded.claudeApiKey, original.claudeApiKey);
      expect(loaded.openaiApiKey, original.openaiApiKey);
      expect(loaded.backend, original.backend);
      expect(loaded.openaiBaseUrl, original.openaiBaseUrl);
      expect(loaded.claudeModelName, original.claudeModelName);
      expect(loaded.openaiModelName, original.openaiModelName);
      expect(loaded.systemPrompt, original.systemPrompt);
      expect(loaded.ttsRate, original.ttsRate);
      expect(loaded.ttsPitch, original.ttsPitch);
      expect(loaded.ttsProvider, original.ttsProvider);
      expect(loaded.elevenLabsApiKey, original.elevenLabsApiKey);
      expect(loaded.elevenLabsVoiceId, original.elevenLabsVoiceId);
      expect(loaded.elevenLabsModelId, original.elevenLabsModelId);
      expect(loaded.openaiTtsVoice, original.openaiTtsVoice);
      expect(loaded.openaiTtsModel, original.openaiTtsModel);
    });
  });
}
