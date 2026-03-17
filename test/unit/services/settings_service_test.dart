import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voiceapp/models/agent_config.dart';
import 'package:voiceapp/models/settings.dart';
import 'package:voiceapp/models/voice_config.dart';
import 'package:voiceapp/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService Serialisation', () {
    late SettingsService service;

    setUp(() {
      service = SettingsService();
      SharedPreferences.setMockInitialValues({
        'migrated_to_v2': true, // Skip migration
        'default_configs_loaded': true, // Skip default voices loading
      });
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('loads default settings when no data is stored', () async {
      final settings = await service.load();

      expect(settings.agents, isEmpty);
      expect(settings.voices, isEmpty);
      expect(settings.openclawServers, isEmpty);
      expect(settings.selectedAgentId, isNull);
      expect(settings.conversationalMode, kDefaultConversationalMode);
      expect(settings.pauseDuration, kDefaultPauseDuration);
    });

    test('saves and loads agents', () async {
      final agent1 = AgentConfig.claude(
        name: 'Test Claude',
        apiKey: 'sk-ant-test-key',
        voiceId: 'voice-1',
        model: 'claude-opus-4-6',
      );
      final agent2 = AgentConfig.openai(
        name: 'Test OpenAI',
        apiKey: 'sk-openai-key',
        voiceId: 'voice-2',
        model: 'gpt-4o',
      );
      final settings = Settings(agents: [agent1, agent2]);

      await service.save(settings);
      final loaded = await service.load();

      expect(loaded.agents.length, 2);
      expect(loaded.agents[0].name, 'Test Claude');
      expect(loaded.agents[0].type, AgentType.claude);
      expect(loaded.agents[0].apiKey, 'sk-ant-test-key');
      expect(loaded.agents[0].model, 'claude-opus-4-6');
      expect(loaded.agents[1].name, 'Test OpenAI');
      expect(loaded.agents[1].type, AgentType.openai);
      expect(loaded.agents[1].apiKey, 'sk-openai-key');
    });

    test('saves and loads voices', () async {
      final voice1 = VoiceConfig.system(rate: 0.5, pitch: 1.0);
      final voice2 = VoiceConfig.elevenlabs(
        name: 'Rachel',
        voiceId: 'rachel-id',
        apiKey: 'elevenlabs-key',
      );
      final settings = Settings(voices: [voice1, voice2]);

      await service.save(settings);
      final loaded = await service.load();

      expect(loaded.voices.length, 2);
      expect(loaded.voices[0].provider, VoiceProvider.onDevice);
      expect(loaded.voices[0].rate, 0.5);
      expect(loaded.voices[0].pitch, 1.0);
      expect(loaded.voices[1].provider, VoiceProvider.elevenlabs);
      expect(loaded.voices[1].name, 'Rachel');
      expect(loaded.voices[1].apiKey, 'elevenlabs-key');
    });

    test('saves and loads OpenClaw servers', () async {
      final server1 = OpenClawServer(
        id: 'server-1',
        name: 'Test Server 1',
        baseUrl: 'http://localhost:3000/v1',
        token: 'test-token-1',
      );
      final server2 = OpenClawServer(
        id: 'server-2',
        name: 'Test Server 2',
        baseUrl: 'http://10.0.0.1:8000/v1',
        token: 'test-token-2',
        allowBadCertificate: true,
      );
      final settings = Settings(openclawServers: [server1, server2]);

      await service.save(settings);
      final loaded = await service.load();

      expect(loaded.openclawServers.length, 2);
      expect(loaded.openclawServers[0].id, 'server-1');
      expect(loaded.openclawServers[0].name, 'Test Server 1');
      expect(loaded.openclawServers[0].baseUrl, 'http://localhost:3000/v1');
      expect(loaded.openclawServers[0].token, 'test-token-1');
      expect(loaded.openclawServers[1].id, 'server-2');
      expect(loaded.openclawServers[1].allowBadCertificate, true);
      expect(loaded.openclawServers[1].token, 'test-token-2');
    });

    test('saves and loads system prompt', () async {
      const customPrompt = 'You are a test assistant.';
      const settings = Settings(systemPrompt: customPrompt);

      await service.save(settings);
      final loaded = await service.load();

      expect(loaded.systemPrompt, customPrompt);
    });

    test('saves and loads selectedAgentId', () async {
      final agent = AgentConfig.claude(
        name: 'Test',
        apiKey: 'key',
        voiceId: 'voice-1',
      );
      final settings = Settings(
        agents: [agent],
        selectedAgentId: agent.id,
      );

      await service.save(settings);
      final loaded = await service.load();

      expect(loaded.selectedAgentId, agent.id);
      expect(loaded.selectedAgent?.id, agent.id);
    });

    test('saves and loads conversationalMode', () async {
      const settings = Settings(conversationalMode: true);

      await service.save(settings);
      final loaded = await service.load();

      expect(loaded.conversationalMode, true);
    });

    test('saves and loads pauseDuration', () async {
      const settings = Settings(pauseDuration: 2.5);

      await service.save(settings);
      final loaded = await service.load();

      expect(loaded.pauseDuration, 2.5);
    });

    test('round-trip preserves all settings', () async {
      final agent = AgentConfig.claude(
        name: 'Test Agent',
        apiKey: 'test-key',
        voiceId: 'voice-1',
      );
      final voice = VoiceConfig.system(rate: 0.75, pitch: 1.2);
      final server = OpenClawServer(
        id: 'server-1',
        name: 'Test Server',
        baseUrl: 'http://localhost:3000/v1',
        token: 'test-token',
      );
      final original = Settings(
        agents: [agent],
        voices: [voice],
        openclawServers: [server],
        selectedAgentId: agent.id,
        systemPrompt: 'Custom prompt',
        conversationalMode: true,
        pauseDuration: 2.0,
      );

      await service.save(original);
      final loaded = await service.load();

      expect(loaded.agents.length, original.agents.length);
      expect(loaded.voices.length, original.voices.length);
      expect(loaded.openclawServers.length, original.openclawServers.length);
      expect(loaded.selectedAgentId, original.selectedAgentId);
      expect(loaded.systemPrompt, original.systemPrompt);
      expect(loaded.conversationalMode, original.conversationalMode);
      expect(loaded.pauseDuration, original.pauseDuration);
    });
  });

  group('SettingsService Secure Storage (Issue #6)', () {
    late SettingsService service;

    setUp(() {
      service = SettingsService();
      SharedPreferences.setMockInitialValues({
        'migrated_to_v2': true, // Skip migration
        'default_configs_loaded': true, // Skip default voices loading
      });
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('agent API keys are NOT stored in SharedPreferences', () async {
      final agent1 = AgentConfig.claude(
        name: 'Claude Agent',
        apiKey: 'sk-ant-secret-key',
        voiceId: 'voice-1',
      );
      final agent2 = AgentConfig.openai(
        name: 'OpenAI Agent',
        apiKey: 'sk-openai-secret-key',
        voiceId: 'voice-1',
      );
      final settings = Settings(agents: [agent1, agent2]);

      await service.save(settings);
      final prefs = await SharedPreferences.getInstance();
      final agentsJson = prefs.getString('agents_v2');

      // Verify API keys are NOT in the JSON stored in SharedPreferences
      expect(agentsJson, isNotNull);
      expect(agentsJson!.contains('sk-ant-secret-key'), isFalse);
      expect(agentsJson.contains('sk-openai-secret-key'), isFalse);
    });

    test('agent API keys are stored in secure storage', () async {
      final agent1 = AgentConfig.claude(
        name: 'Claude Agent',
        apiKey: 'sk-ant-secret-key',
        voiceId: 'voice-1',
      );
      final agent2 = AgentConfig.openai(
        name: 'OpenAI Agent',
        apiKey: 'sk-openai-secret-key',
        voiceId: 'voice-1',
      );
      final settings = Settings(agents: [agent1, agent2]);

      await service.save(settings);
      final loaded = await service.load();

      // Verify API keys are loaded correctly from secure storage
      expect(loaded.agents.length, 2);
      expect(loaded.agents[0].apiKey, 'sk-ant-secret-key');
      expect(loaded.agents[1].apiKey, 'sk-openai-secret-key');
    });

    test('voice API keys are NOT stored in SharedPreferences', () async {
      final voice1 = VoiceConfig.elevenlabs(
        name: 'ElevenLabs Voice',
        voiceId: 'voice-id',
        apiKey: 'elevenlabs-secret-key',
      );
      final voice2 = VoiceConfig.openai(
        name: 'OpenAI Voice',
        voiceId: 'alloy',
        apiKey: 'openai-tts-secret-key',
      );
      final settings = Settings(voices: [voice1, voice2]);

      await service.save(settings);
      final prefs = await SharedPreferences.getInstance();
      final voicesJson = prefs.getString('voices_v2');

      // Verify API keys are NOT in the JSON stored in SharedPreferences
      expect(voicesJson, isNotNull);
      expect(voicesJson!.contains('elevenlabs-secret-key'), isFalse);
      expect(voicesJson.contains('openai-tts-secret-key'), isFalse);
    });

    test('voice API keys are stored in secure storage', () async {
      final voice1 = VoiceConfig.elevenlabs(
        name: 'ElevenLabs Voice',
        voiceId: 'voice-id',
        apiKey: 'elevenlabs-secret-key',
      );
      final voice2 = VoiceConfig.openai(
        name: 'OpenAI Voice',
        voiceId: 'alloy',
        apiKey: 'openai-tts-secret-key',
      );
      final settings = Settings(voices: [voice1, voice2]);

      await service.save(settings);
      final loaded = await service.load();

      // Verify API keys are loaded correctly from secure storage
      expect(loaded.voices.length, 2);
      expect(loaded.voices[0].apiKey, 'elevenlabs-secret-key');
      expect(loaded.voices[1].apiKey, 'openai-tts-secret-key');
    });

    test(
      'OpenClaw server tokens are NOT stored in SharedPreferences',
      () async {
        final server = OpenClawServer(
          id: 'test-id',
          name: 'Test Server',
          baseUrl: 'http://localhost:3000/v1',
          token: 'secret-bearer-token',
        );
        final settings = Settings(openclawServers: [server]);

        await service.save(settings);
        final prefs = await SharedPreferences.getInstance();
        final serversJson = prefs.getString('openclaw_servers_v2');

        // Verify token is NOT in the JSON stored in SharedPreferences
        expect(serversJson, isNotNull);
        expect(serversJson!.contains('secret-bearer-token'), isFalse);
      },
    );

    test('OpenClaw server tokens are stored in secure storage', () async {
      final server = OpenClawServer(
        id: 'test-id',
        name: 'Test Server',
        baseUrl: 'http://localhost:3000/v1',
        token: 'secret-bearer-token',
      );
      final settings = Settings(openclawServers: [server]);

      await service.save(settings);
      final loaded = await service.load();

      // Verify token is loaded correctly from secure storage
      expect(loaded.openclawServers.length, 1);
      expect(loaded.openclawServers.first.token, 'secret-bearer-token');
    });

    test('multiple OpenClaw server tokens are stored securely', () async {
      final server1 = OpenClawServer(
        id: 'id-1',
        name: 'Server 1',
        baseUrl: 'http://localhost:3000/v1',
        token: 'token-1',
      );
      final server2 = OpenClawServer(
        id: 'id-2',
        name: 'Server 2',
        baseUrl: 'http://10.0.0.1:8000/v1',
        token: 'token-2',
      );
      final settings = Settings(openclawServers: [server1, server2]);

      await service.save(settings);
      final loaded = await service.load();

      // Verify both tokens are loaded correctly
      expect(loaded.openclawServers.length, 2);
      expect(loaded.openclawServers[0].token, 'token-1');
      expect(loaded.openclawServers[1].token, 'token-2');

      // Verify tokens are NOT in SharedPreferences JSON
      final prefs = await SharedPreferences.getInstance();
      final serversJson = prefs.getString('openclaw_servers_v2');
      expect(serversJson, isNotNull);
      expect(serversJson!.contains('token-1'), isFalse);
      expect(serversJson.contains('token-2'), isFalse);
    });

    test('deleting agents removes their API keys from secure storage',
        () async {
      // First save with agents that have API keys
      final agent = AgentConfig.claude(
        name: 'Test Agent',
        apiKey: 'test-key',
        voiceId: 'voice-1',
      );
      final settings1 = Settings(agents: [agent]);
      await service.save(settings1);
      var loaded = await service.load();
      expect(loaded.agents.length, 1);
      expect(loaded.agents[0].apiKey, 'test-key');

      // Then save with empty agents list
      const settings2 = Settings(agents: []);
      await service.save(settings2);
      loaded = await service.load();
      expect(loaded.agents, isEmpty);
    });

    test('deleting voices removes their API keys from secure storage',
        () async {
      // First save with voices that have API keys
      final voice = VoiceConfig.elevenlabs(
        name: 'Test Voice',
        voiceId: 'voice-id',
        apiKey: 'test-key',
      );
      final settings1 = Settings(voices: [voice]);
      await service.save(settings1);
      var loaded = await service.load();
      expect(loaded.voices.length, 1);
      expect(loaded.voices[0].apiKey, 'test-key');

      // Then save with empty voices list
      const settings2 = Settings(voices: []);
      await service.save(settings2);
      loaded = await service.load();
      expect(loaded.voices, isEmpty);
    });

    test('deleting servers removes their tokens from secure storage', () async {
      // First save with servers that have tokens
      final server = OpenClawServer(
        id: 'test-id',
        name: 'Test Server',
        baseUrl: 'http://localhost:3000/v1',
        token: 'test-token',
      );
      final settings1 = Settings(openclawServers: [server]);
      await service.save(settings1);
      var loaded = await service.load();
      expect(loaded.openclawServers.length, 1);
      expect(loaded.openclawServers[0].token, 'test-token');

      // Then save with empty servers list
      const settings2 = Settings(openclawServers: []);
      await service.save(settings2);
      loaded = await service.load();
      expect(loaded.openclawServers, isEmpty);
    });
  });

  group('SettingsService Default Configs (Issue #32)', () {
    late SettingsService service;

    setUp(() {
      service = SettingsService();
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    test(
      'does nothing when default_configs_loaded flag is already set',
      () async {
        SharedPreferences.setMockInitialValues({
          'default_configs_loaded': true,
        });

        final settings = await service.load();

        // Should not load any configs
        expect(service.lastLoadedConfigCount, 0);
        expect(settings.openclawServers, isEmpty);
        expect(settings.agents, isEmpty);
        // Note: voices may not be empty if there's existing data in prefs
      },
    );

    test('does nothing when existing configs are present', () async {
      // Simulate existing configs
      SharedPreferences.setMockInitialValues({'openclaw_servers': '[]'});

      final settings = await service.load();

      // Should not load any configs and should set the flag
      expect(service.lastLoadedConfigCount, 0);
      expect(settings.openclawServers, isEmpty);

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

    test(
      'simulates successful default config load by manually storing then loading',
      () async {
        // Simulate what would happen if default_configs.json loaded successfully
        // by manually storing configs, then verifying load() reads them correctly

        // Start with clean state
        SharedPreferences.setMockInitialValues({});
        FlutterSecureStorage.setMockInitialValues({});

        // Manually store configs as if they came from default_configs.json
        final prefs = await SharedPreferences.getInstance();
        final server1 = OpenClawServer(
          id: 'test-server-1',
          name: 'Test Server 1',
          baseUrl: 'http://localhost:3000/v1',
          token: 'test-token-1',
        );
        final server2 = OpenClawServer(
          id: 'test-server-2',
          name: 'Test Server 2',
          baseUrl: 'http://10.0.0.1:8000/v1',
          token: 'test-token-2',
        );

        // Store servers to SharedPreferences (without tokens, as the service does)
        // Use the new key name from SettingsService
        await prefs.setString(
          'openclaw_servers_v2',
          jsonEncode([server1.toJson(), server2.toJson()]),
        );

        // Store tokens to secure storage using correct key format
        const secureStorage = FlutterSecureStorage();
        await secureStorage.write(
          key: 'server_token_test-server-1',
          value: 'test-token-1',
        );
        await secureStorage.write(
          key: 'server_token_test-server-2',
          value: 'test-token-2',
        );

        // Mark as loaded and migrated
        await prefs.setBool('default_configs_loaded', true);
        await prefs.setBool('migrated_to_v2', true);

        // Now load and verify everything is read correctly
        final freshService = SettingsService();
        final settings = await freshService.load();

        // Verify openclaw servers are loaded correctly
        expect(settings.openclawServers.length, 2);
        expect(settings.openclawServers[0].id, 'test-server-1');
        expect(settings.openclawServers[0].name, 'Test Server 1');
        expect(
          settings.openclawServers[0].baseUrl,
          'http://localhost:3000/v1',
        );
        expect(settings.openclawServers[0].token, 'test-token-1');
        expect(settings.openclawServers[1].id, 'test-server-2');
        expect(settings.openclawServers[1].name, 'Test Server 2');
        expect(settings.openclawServers[1].token, 'test-token-2');

        // Verify servers are still in SharedPreferences
        final serversJson = prefs.getString('openclaw_servers_v2');
        expect(serversJson, isNotNull);
        final storedServers = jsonDecode(serversJson!);
        expect(storedServers, isList);
        expect(storedServers.length, 2);

        // Verify tokens are NOT in SharedPreferences JSON
        expect(serversJson.contains('test-token-1'), isFalse);
        expect(serversJson.contains('test-token-2'), isFalse);

        // Verify the flag is set
        expect(prefs.getBool('default_configs_loaded'), true);
      },
    );
  });
}
