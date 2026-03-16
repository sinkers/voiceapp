import 'package:flutter_test/flutter_test.dart';
import 'package:voiceapp/models/elevenlabs_voice.dart';
import 'package:voiceapp/models/settings.dart';

void main() {
  group('Settings Model', () {
    test('default constructor creates settings with default values', () {
      const settings = Settings();

      expect(settings.claudeApiKey, isNull);
      expect(settings.openaiApiKey, isNull);
      expect(settings.backend, LLMBackend.claude);
      expect(settings.openaiBaseUrl, 'https://api.openai.com/v1');
      expect(settings.claudeModelName, 'claude-opus-4-6');
      expect(settings.openaiModelName, 'gpt-4o');
      expect(settings.ttsRate, 0.5);
      expect(settings.ttsPitch, 1.0);
      expect(settings.openclawInstances, isEmpty);
      expect(settings.selectedInstanceId, isNull);
      expect(settings.selectedAgentId, isNull);
      expect(settings.ttsProvider, TtsProvider.onDevice);
      expect(settings.conversationalMode, false);
      expect(settings.pauseDuration, 1.5);
    });

    test('copyWith preserves unchanged values', () {
      const original = Settings(
        claudeApiKey: 'test-key',
        backend: LLMBackend.claude,
        ttsRate: 0.75,
      );

      final copied = original.copyWith(ttsRate: 0.8);

      expect(copied.claudeApiKey, 'test-key');
      expect(copied.backend, LLMBackend.claude);
      expect(copied.ttsRate, 0.8);
    });

    test('copyWith updates specific values', () {
      const original = Settings();

      final updated = original.copyWith(
        claudeApiKey: 'new-key',
        backend: LLMBackend.openaiCompatible,
        ttsRate: 0.9,
      );

      expect(updated.claudeApiKey, 'new-key');
      expect(updated.backend, LLMBackend.openaiCompatible);
      expect(updated.ttsRate, 0.9);
    });

    test('copyWith can clear API keys with clear flags', () {
      const original = Settings(
        claudeApiKey: 'test-key',
        openaiApiKey: 'openai-key',
      );

      final cleared = original.copyWith(
        clearClaudeApiKey: true,
        clearOpenaiApiKey: true,
      );

      expect(cleared.claudeApiKey, isNull);
      expect(cleared.openaiApiKey, isNull);
    });

    test('copyWith can clear selected instance', () {
      const original = Settings(
        selectedInstanceId: 'test-id',
        selectedAgentId: 'agent-id',
      );

      final cleared = original.copyWith(
        clearSelectedInstanceId: true,
        clearSelectedAgentId: true,
      );

      expect(cleared.selectedInstanceId, isNull);
      expect(cleared.selectedAgentId, isNull);
    });

    test('activeModelName returns correct model based on backend', () {
      const claudeSettings = Settings(
        backend: LLMBackend.claude,
        claudeModelName: 'claude-test',
        openaiModelName: 'gpt-test',
      );

      expect(claudeSettings.activeModelName, 'claude-test');

      const openaiSettings = Settings(
        backend: LLMBackend.openaiCompatible,
        claudeModelName: 'claude-test',
        openaiModelName: 'gpt-test',
      );

      expect(openaiSettings.activeModelName, 'gpt-test');
    });

    test('copyWith updates conversational mode settings', () {
      const original = Settings(
        conversationalMode: false,
        pauseDuration: 1.5,
      );

      final updated = original.copyWith(
        conversationalMode: true,
        pauseDuration: 2.5,
      );

      expect(updated.conversationalMode, true);
      expect(updated.pauseDuration, 2.5);
    });

    test('selectedInstance returns correct instance by ID', () {
      const instance1 = OpenClawInstance(
        id: 'id-1',
        name: 'Instance 1',
        baseUrl: 'http://localhost:3000/v1',
        sessionId: 'session-1',
      );
      const instance2 = OpenClawInstance(
        id: 'id-2',
        name: 'Instance 2',
        baseUrl: 'http://localhost:8000/v1',
        sessionId: 'session-2',
      );

      const settings = Settings(
        openclawInstances: [instance1, instance2],
        selectedInstanceId: 'id-2',
      );

      expect(settings.selectedInstance, instance2);
      expect(settings.selectedInstance?.id, 'id-2');
    });

    test('selectedInstance returns null when no instance is selected', () {
      const instance = OpenClawInstance(
        id: 'id-1',
        name: 'Instance 1',
        baseUrl: 'http://localhost:3000/v1',
        sessionId: 'session-1',
      );

      const settings = Settings(
        openclawInstances: [instance],
        selectedInstanceId: null,
      );

      expect(settings.selectedInstance, isNull);
    });

    test('selectedInstance returns null when selected ID does not exist', () {
      const instance = OpenClawInstance(
        id: 'id-1',
        name: 'Instance 1',
        baseUrl: 'http://localhost:3000/v1',
        sessionId: 'session-1',
      );

      const settings = Settings(
        openclawInstances: [instance],
        selectedInstanceId: 'non-existent-id',
      );

      expect(settings.selectedInstance, isNull);
    });
  });

  group('OpenClawInstance Model', () {
    test('creates instance with required fields', () {
      const instance = OpenClawInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'http://localhost:3000/v1',
        sessionId: 'test-session',
      );

      expect(instance.id, 'test-id');
      expect(instance.name, 'Test Instance');
      expect(instance.baseUrl, 'http://localhost:3000/v1');
      expect(instance.token, '');
      expect(instance.sessionId, 'test-session');
    });

    test('creates instance with token', () {
      const instance = OpenClawInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'http://localhost:3000/v1',
        token: 'test-token',
        sessionId: 'test-session',
      );

      expect(instance.token, 'test-token');
    });

    test('toJson serialises correctly', () {
      const instance = OpenClawInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'http://localhost:3000/v1',
        token: 'test-token',
        sessionId: 'test-session',
      );

      final json = instance.toJson();

      expect(json['id'], 'test-id');
      expect(json['name'], 'Test Instance');
      expect(json['baseUrl'], 'http://localhost:3000/v1');
      // Token is excluded from JSON (stored in secure storage instead)
      expect(json.containsKey('token'), isFalse);
      expect(json['sessionId'], 'test-session');
      expect(json['elevenLabsVoiceId'], ElevenLabsVoice.rachel.voiceId);
      expect(json['elevenLabsSpeed'], 1.1);
    });

    test('fromJson deserialises correctly', () {
      final json = {
        'id': 'test-id',
        'name': 'Test Instance',
        'baseUrl': 'http://localhost:3000/v1',
        'token': 'test-token',
        'sessionId': 'test-session',
        'elevenLabsVoiceId': ElevenLabsVoice.liam.voiceId,
        'elevenLabsSpeed': 1.0,
      };

      final instance = OpenClawInstance.fromJson(json);

      expect(instance.id, 'test-id');
      expect(instance.name, 'Test Instance');
      expect(instance.baseUrl, 'http://localhost:3000/v1');
      expect(instance.token, 'test-token');
      expect(instance.sessionId, 'test-session');
      expect(instance.elevenLabsVoice, ElevenLabsVoice.liam);
      expect(instance.elevenLabsSpeed, 1.0);
    });

    test('fromJson handles missing token', () {
      final json = {
        'id': 'test-id',
        'name': 'Test Instance',
        'baseUrl': 'http://localhost:3000/v1',
        'sessionId': 'test-session',
      };

      final instance = OpenClawInstance.fromJson(json);

      expect(instance.token, '');
      expect(instance.elevenLabsVoice, ElevenLabsVoice.rachel);
      expect(instance.elevenLabsSpeed, 1.1);
    });

    test(
      'fromJson generates sessionId if missing (backward compatibility)',
      () {
        final json = {
          'id': 'test-id',
          'name': 'Test Instance',
          'baseUrl': 'http://localhost:3000/v1',
          'token': 'test-token',
        };

        final instance = OpenClawInstance.fromJson(json);

        expect(instance.sessionId, isNotEmpty);
        expect(instance.sessionId.length, 36); // UUID v4 format
      },
    );

    test(
      'two instances created from JSON without sessionId have different IDs',
      () {
        final json = {
          'id': 'test-id',
          'name': 'Test Instance',
          'baseUrl': 'http://localhost:3000/v1',
        };

        final instance1 = OpenClawInstance.fromJson(json);
        final instance2 = OpenClawInstance.fromJson(json);

        expect(instance1.sessionId, isNot(equals(instance2.sessionId)));
      },
    );

    test('round-trip serialisation preserves data', () {
      const original = OpenClawInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'http://localhost:3000/v1',
        token: 'test-token',
        sessionId: 'test-session',
      );

      final json = original.toJson();
      final deserialized = OpenClawInstance.fromJson(json);

      expect(deserialized.id, original.id);
      expect(deserialized.name, original.name);
      expect(deserialized.baseUrl, original.baseUrl);
      // Token is excluded from JSON serialization (stored in secure storage)
      // so it defaults to empty string when deserialized
      expect(deserialized.token, '');
      expect(deserialized.sessionId, original.sessionId);
      expect(deserialized.elevenLabsVoice, original.elevenLabsVoice);
      expect(deserialized.elevenLabsSpeed, original.elevenLabsSpeed);
    });

    test('copyWith creates copy with updated fields', () {
      const original = OpenClawInstance(
        id: 'id-1',
        name: 'Original',
        baseUrl: 'http://old:3000/v1',
        token: 'old-token',
        sessionId: 'session-1',
      );

      final updated = original.copyWith(
        name: 'Updated',
        baseUrl: 'http://new:3000/v1',
      );

      expect(updated.id, 'id-1');
      expect(updated.name, 'Updated');
      expect(updated.baseUrl, 'http://new:3000/v1');
      expect(updated.token, 'old-token');
      expect(updated.sessionId, 'session-1');
      expect(updated.elevenLabsVoice, original.elevenLabsVoice);
      expect(updated.elevenLabsSpeed, original.elevenLabsSpeed);
    });

    test('copyWith can update sessionId', () {
      const original = OpenClawInstance(
        id: 'id-1',
        name: 'Instance',
        baseUrl: 'http://localhost:3000/v1',
        sessionId: 'old-session',
      );

      final updated = original.copyWith(sessionId: 'new-session');

      expect(updated.sessionId, 'new-session');
      expect(updated.id, original.id);
      expect(updated.name, original.name);
    });
  });

  group('Enums', () {
    test('LLMBackend has expected values', () {
      expect(LLMBackend.values.length, 2);
      expect(LLMBackend.values, contains(LLMBackend.claude));
      expect(LLMBackend.values, contains(LLMBackend.openaiCompatible));
    });

    test('TtsProvider has expected values', () {
      expect(TtsProvider.values.length, 3);
      expect(TtsProvider.values, contains(TtsProvider.onDevice));
      expect(TtsProvider.values, contains(TtsProvider.elevenlabs));
      expect(TtsProvider.values, contains(TtsProvider.openai));
    });
  });

  group('Settings.allAgents', () {
    test('returns 2 direct agents when no instances configured', () {
      const settings = Settings();

      final agents = settings.allAgents;

      expect(agents.length, 2);
      expect(agents[0].runtimeType.toString(), 'DirectModelAgentConfig');
      expect(agents[1].runtimeType.toString(), 'DirectModelAgentConfig');
    });

    test('returns correct count with 2 instances with 1 agent each', () {
      const settings = Settings(
        openclawInstances: [
          OpenClawInstance(
            id: 'inst-1',
            name: 'Instance 1',
            baseUrl: 'http://localhost:3000/v1',
            sessionId: 'session-1',
            agentIds: ['main'],
          ),
          OpenClawInstance(
            id: 'inst-2',
            name: 'Instance 2',
            baseUrl: 'http://localhost:4000/v1',
            sessionId: 'session-2',
            agentIds: ['main'],
          ),
        ],
      );

      final agents = settings.allAgents;

      // 2 OpenClaw agents (1 per instance) + 2 direct agents = 4 total
      expect(agents.length, 4);
    });

    test('expands multi-agent instances correctly', () {
      const settings = Settings(
        openclawInstances: [
          OpenClawInstance(
            id: 'inst-1',
            name: 'Multi-Agent Instance',
            baseUrl: 'http://localhost:3000/v1',
            sessionId: 'session-1',
            agentIds: ['main', 'elysse'],
          ),
        ],
      );

      final agents = settings.allAgents;

      // 2 OpenClaw agents (from one instance with 2 agentIds) + 2 direct = 4
      expect(agents.length, 4);
    });

    test('allAgents includes correct mix of OpenClaw and direct agents', () {
      const settings = Settings(
        openclawInstances: [
          OpenClawInstance(
            id: 'inst-1',
            name: 'Instance 1',
            baseUrl: 'http://localhost:3000/v1',
            sessionId: 'session-1',
            agentIds: ['main', 'alex'],
          ),
          OpenClawInstance(
            id: 'inst-2',
            name: 'Instance 2',
            baseUrl: 'http://localhost:4000/v1',
            sessionId: 'session-2',
            agentIds: ['elysse'],
          ),
        ],
      );

      final agents = settings.allAgents;

      // 3 OpenClaw (2 from inst-1, 1 from inst-2) + 2 direct = 5
      expect(agents.length, 5);
    });
  });

  group('OpenClawInstance serialization', () {
    test('toJson includes agentIds', () {
      const instance = OpenClawInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'http://localhost:3000/v1',
        sessionId: 'test-session',
        agentIds: ['main', 'elysse'],
      );

      final json = instance.toJson();

      expect(json['agentIds'], ['main', 'elysse']);
    });

    test('fromJson preserves agentIds', () {
      final json = {
        'id': 'test-id',
        'name': 'Test Instance',
        'baseUrl': 'http://localhost:3000/v1',
        'sessionId': 'test-session',
        'agentIds': ['main', 'alex', 'elysse'],
      };

      final instance = OpenClawInstance.fromJson(json);

      expect(instance.agentIds, ['main', 'alex', 'elysse']);
    });

    test('fromJson defaults agentIds to ["main"] when missing', () {
      final json = {
        'id': 'test-id',
        'name': 'Test Instance',
        'baseUrl': 'http://localhost:3000/v1',
        'sessionId': 'test-session',
      };

      final instance = OpenClawInstance.fromJson(json);

      expect(instance.agentIds, ['main']);
    });

    test('round-trip serialization preserves agentIds', () {
      const original = OpenClawInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'http://localhost:3000/v1',
        sessionId: 'test-session',
        agentIds: ['main', 'elysse', 'alex'],
      );

      final json = original.toJson();
      final deserialized = OpenClawInstance.fromJson(json);

      expect(deserialized.agentIds, original.agentIds);
    });
  });
}
