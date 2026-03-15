import 'package:flutter_test/flutter_test.dart';
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

    test('selectedInstance returns correct instance by ID', () {
      const instance1 = OpenClawInstance(
        id: 'id-1',
        name: 'Instance 1',
        baseUrl: 'http://localhost:3000/v1',
      );
      const instance2 = OpenClawInstance(
        id: 'id-2',
        name: 'Instance 2',
        baseUrl: 'http://localhost:8000/v1',
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
      );

      expect(instance.id, 'test-id');
      expect(instance.name, 'Test Instance');
      expect(instance.baseUrl, 'http://localhost:3000/v1');
      expect(instance.token, '');
    });

    test('creates instance with token', () {
      const instance = OpenClawInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'http://localhost:3000/v1',
        token: 'test-token',
      );

      expect(instance.token, 'test-token');
    });

    test('toJson serialises correctly', () {
      const instance = OpenClawInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'http://localhost:3000/v1',
        token: 'test-token',
      );

      final json = instance.toJson();

      expect(json['id'], 'test-id');
      expect(json['name'], 'Test Instance');
      expect(json['baseUrl'], 'http://localhost:3000/v1');
      expect(json['token'], 'test-token');
    });

    test('fromJson deserialises correctly', () {
      final json = {
        'id': 'test-id',
        'name': 'Test Instance',
        'baseUrl': 'http://localhost:3000/v1',
        'token': 'test-token',
      };

      final instance = OpenClawInstance.fromJson(json);

      expect(instance.id, 'test-id');
      expect(instance.name, 'Test Instance');
      expect(instance.baseUrl, 'http://localhost:3000/v1');
      expect(instance.token, 'test-token');
    });

    test('fromJson handles missing token', () {
      final json = {
        'id': 'test-id',
        'name': 'Test Instance',
        'baseUrl': 'http://localhost:3000/v1',
      };

      final instance = OpenClawInstance.fromJson(json);

      expect(instance.token, '');
    });

    test('round-trip serialisation preserves data', () {
      const original = OpenClawInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'http://localhost:3000/v1',
        token: 'test-token',
      );

      final json = original.toJson();
      final deserialized = OpenClawInstance.fromJson(json);

      expect(deserialized.id, original.id);
      expect(deserialized.name, original.name);
      expect(deserialized.baseUrl, original.baseUrl);
      expect(deserialized.token, original.token);
    });

    test('copyWith creates copy with updated fields', () {
      const original = OpenClawInstance(
        id: 'id-1',
        name: 'Original',
        baseUrl: 'http://old:3000/v1',
        token: 'old-token',
      );

      final updated = original.copyWith(
        name: 'Updated',
        baseUrl: 'http://new:3000/v1',
      );

      expect(updated.id, 'id-1');
      expect(updated.name, 'Updated');
      expect(updated.baseUrl, 'http://new:3000/v1');
      expect(updated.token, 'old-token');
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
}
