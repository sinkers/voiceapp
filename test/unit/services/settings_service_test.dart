import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
      FlutterSecureStorage.setMockInitialValues({});
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
        sessionId: 'test-session',
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
        loaded.openclawInstances.first.baseUrl,
        'http://localhost:3000/v1',
      );
      expect(loaded.openclawInstances.first.token, 'test-token');
      expect(loaded.openclawInstances.first.sessionId, 'test-session');
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
        sessionId: 'session-1',
      );
      const instance2 = OpenClawInstance(
        id: 'id-2',
        name: 'Instance 2',
        baseUrl: 'http://10.0.0.1:8000/v1',
        token: 'token-2',
        sessionId: 'session-2',
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

  group('SettingsService Secure Storage (Issue #6)', () {
    late SettingsService service;

    setUp(() {
      service = SettingsService();
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('API keys are NOT stored in SharedPreferences', () async {
      const settings = Settings(
        claudeApiKey: 'sk-ant-secret-key',
        openaiApiKey: 'sk-openai-secret-key',
        elevenLabsApiKey: 'elevenlabs-secret-key',
      );

      await service.save(settings);
      final prefs = await SharedPreferences.getInstance();

      // Verify API keys are NOT in SharedPreferences
      expect(prefs.getString('claude_api_key'), isNull);
      expect(prefs.getString('openai_api_key'), isNull);
      expect(prefs.getString('elevenlabs_api_key'), isNull);
    });

    test('API keys are stored in secure storage', () async {
      const settings = Settings(
        claudeApiKey: 'sk-ant-secret-key',
        openaiApiKey: 'sk-openai-secret-key',
        elevenLabsApiKey: 'elevenlabs-secret-key',
      );

      await service.save(settings);
      final loaded = await service.load();

      // Verify API keys are loaded correctly from secure storage
      expect(loaded.claudeApiKey, 'sk-ant-secret-key');
      expect(loaded.openaiApiKey, 'sk-openai-secret-key');
      expect(loaded.elevenLabsApiKey, 'elevenlabs-secret-key');
    });

    test('OpenClaw instance tokens are NOT stored in SharedPreferences',
        () async {
      const instance = OpenClawInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'http://localhost:3000/v1',
        token: 'secret-bearer-token',
        sessionId: 'test-session',
      );
      const settings = Settings(openclawInstances: [instance]);

      await service.save(settings);
      final prefs = await SharedPreferences.getInstance();
      final instancesJson = prefs.getString('openclaw_instances');

      // Verify token is NOT in the JSON stored in SharedPreferences
      expect(instancesJson, isNotNull);
      expect(instancesJson!.contains('secret-bearer-token'), isFalse);
    });

    test('OpenClaw instance tokens are stored in secure storage', () async {
      const instance = OpenClawInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'http://localhost:3000/v1',
        token: 'secret-bearer-token',
        sessionId: 'test-session',
      );
      const settings = Settings(openclawInstances: [instance]);

      await service.save(settings);
      final loaded = await service.load();

      // Verify token is loaded correctly from secure storage
      expect(loaded.openclawInstances.length, 1);
      expect(loaded.openclawInstances.first.token, 'secret-bearer-token');
    });

    test('multiple OpenClaw instance tokens are stored securely', () async {
      const instance1 = OpenClawInstance(
        id: 'id-1',
        name: 'Instance 1',
        baseUrl: 'http://localhost:3000/v1',
        token: 'token-1',
        sessionId: 'session-1',
      );
      const instance2 = OpenClawInstance(
        id: 'id-2',
        name: 'Instance 2',
        baseUrl: 'http://10.0.0.1:8000/v1',
        token: 'token-2',
        sessionId: 'session-2',
      );
      const settings = Settings(openclawInstances: [instance1, instance2]);

      await service.save(settings);
      final loaded = await service.load();

      // Verify both tokens are loaded correctly
      expect(loaded.openclawInstances.length, 2);
      expect(loaded.openclawInstances[0].token, 'token-1');
      expect(loaded.openclawInstances[1].token, 'token-2');

      // Verify tokens are NOT in SharedPreferences JSON
      final prefs = await SharedPreferences.getInstance();
      final instancesJson = prefs.getString('openclaw_instances');
      expect(instancesJson, isNotNull);
      expect(instancesJson!.contains('token-1'), isFalse);
      expect(instancesJson.contains('token-2'), isFalse);
    });

    test('deleting API keys removes them from secure storage', () async {
      // First save with API keys
      const settings1 = Settings(
        claudeApiKey: 'test-key',
        openaiApiKey: 'test-key-2',
        elevenLabsApiKey: 'test-key-3',
      );
      await service.save(settings1);
      var loaded = await service.load();
      expect(loaded.claudeApiKey, 'test-key');
      expect(loaded.openaiApiKey, 'test-key-2');
      expect(loaded.elevenLabsApiKey, 'test-key-3');

      // Then save with null API keys
      const settings2 = Settings(
        claudeApiKey: null,
        openaiApiKey: null,
        elevenLabsApiKey: null,
      );
      await service.save(settings2);
      loaded = await service.load();
      expect(loaded.claudeApiKey, isNull);
      expect(loaded.openaiApiKey, isNull);
      expect(loaded.elevenLabsApiKey, isNull);
    });
  });

  group('SettingsService Default Configs (Issue #32)', () {
    late SettingsService service;

    setUp(() {
      service = SettingsService();
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('does nothing when default_configs_loaded flag is already set',
        () async {
      SharedPreferences.setMockInitialValues({
        'default_configs_loaded': true,
      });

      final settings = await service.load();

      // Should not load any configs
      expect(service.lastLoadedConfigCount, 0);
      expect(settings.openclawInstances, isEmpty);
    });

    test('does nothing when existing configs are present', () async {
      // Simulate existing configs
      SharedPreferences.setMockInitialValues({
        'openclaw_instances': '[]',
      });

      final settings = await service.load();

      // Should not load any configs and should set the flag
      expect(service.lastLoadedConfigCount, 0);
      expect(settings.openclawInstances, isEmpty);

      // Verify flag was set
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('default_configs_loaded'), true);
    });

    test('does nothing when asset has empty arrays', () async {
      // The actual default_configs.json file has empty arrays
      await service.load();

      // Should not load any configs but should set the flag
      expect(service.lastLoadedConfigCount, 0);

      // Verify flag was set
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('default_configs_loaded'), true);
    });

    test('sets flag even when asset loading fails', () async {
      // This will fail to load the asset in test environment
      await service.load();

      // Should set the flag even on failure to avoid retrying
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('default_configs_loaded'), true);

      // Count should be 0 since loading failed
      expect(service.lastLoadedConfigCount, 0);
    });

    test('only loads configs once on repeated calls', () async {
      // First load
      await service.load();

      // Second load
      await service.load();

      // Should return 0 on second load since flag is set
      expect(service.lastLoadedConfigCount, 0);
    });
  });
}
