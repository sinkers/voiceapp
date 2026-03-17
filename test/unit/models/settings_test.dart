import 'package:flutter_test/flutter_test.dart';
import 'package:voiceapp/models/agent_config.dart';
import 'package:voiceapp/models/elevenlabs_voice.dart';
import 'package:voiceapp/models/settings.dart';
import 'package:voiceapp/models/voice_config.dart';

void main() {
  group('Settings Model', () {
    test('default constructor creates settings with default values', () {
      const settings = Settings();

      expect(settings.agents, isEmpty);
      expect(settings.voices, isEmpty);
      expect(settings.openclawServers, isEmpty);
      expect(settings.selectedAgentId, isNull);
      expect(settings.conversationalMode, false);
      expect(settings.pauseDuration, 1.5);
      expect(settings.systemPrompt, contains('helpful voice assistant'));
    });

    test('copyWith preserves unchanged values', () {
      final agent1 = AgentConfig.claude(
        name: 'Claude',
        apiKey: 'key-1',
        voiceId: 'voice-1',
      );
      final voice1 = VoiceConfig.system();

      final original = Settings(
        agents: [agent1],
        voices: [voice1],
        conversationalMode: true,
        pauseDuration: 2.0,
      );

      final copied = original.copyWith(pauseDuration: 2.5);

      expect(copied.agents, original.agents);
      expect(copied.voices, original.voices);
      expect(copied.conversationalMode, true);
      expect(copied.pauseDuration, 2.5);
    });

    test('copyWith updates specific values', () {
      const original = Settings();

      final agent1 = AgentConfig.claude(
        name: 'New Agent',
        apiKey: 'key-1',
        voiceId: 'voice-1',
      );

      final updated = original.copyWith(
        agents: [agent1],
        conversationalMode: true,
        pauseDuration: 2.0,
      );

      expect(updated.agents.length, 1);
      expect(updated.agents[0].name, 'New Agent');
      expect(updated.conversationalMode, true);
      expect(updated.pauseDuration, 2.0);
    });

    test('copyWith can clear selectedAgentId', () {
      const original = Settings(selectedAgentId: 'agent-id-1');

      final cleared = original.copyWith(clearSelectedAgentId: true);

      expect(cleared.selectedAgentId, isNull);
    });

    test('copyWith updates conversational mode settings', () {
      const original = Settings(conversationalMode: false, pauseDuration: 1.5);

      final updated = original.copyWith(
        conversationalMode: true,
        pauseDuration: 2.5,
      );

      expect(updated.conversationalMode, true);
      expect(updated.pauseDuration, 2.5);
    });

    test('selectedAgent returns correct agent by ID', () {
      final agent1 = AgentConfig.claude(
        name: 'Claude 1',
        apiKey: 'key-1',
        voiceId: 'voice-1',
      );
      final agent2 = AgentConfig.openai(
        name: 'GPT 1',
        apiKey: 'key-2',
        voiceId: 'voice-1',
      );

      final settings = Settings(
        agents: [agent1, agent2],
        selectedAgentId: agent2.id,
      );

      expect(settings.selectedAgent, agent2);
      expect(settings.selectedAgent?.id, agent2.id);
    });

    test('selectedAgent returns null when no agent is selected', () {
      final agent = AgentConfig.claude(
        name: 'Claude',
        apiKey: 'key-1',
        voiceId: 'voice-1',
      );

      final settings = Settings(
        agents: [agent],
        selectedAgentId: null,
      );

      expect(settings.selectedAgent, isNull);
    });

    test('selectedAgent returns null when selected ID does not exist', () {
      final agent = AgentConfig.claude(
        name: 'Claude',
        apiKey: 'key-1',
        voiceId: 'voice-1',
      );

      final settings = Settings(
        agents: [agent],
        selectedAgentId: 'non-existent-id',
      );

      expect(settings.selectedAgent, isNull);
    });

    test('getVoiceById returns correct voice', () {
      final voice1 = VoiceConfig.system();
      final voice2 = VoiceConfig.elevenlabs(
        name: 'ElevenLabs Voice',
        voiceId: 'test-voice-id',
      );

      final settings = Settings(voices: [voice1, voice2]);

      expect(settings.getVoiceById(voice2.id), voice2);
      expect(settings.getVoiceById(voice2.id)?.name, 'ElevenLabs Voice');
    });

    test('getVoiceById returns null for non-existent ID', () {
      final voice = VoiceConfig.system();
      final settings = Settings(voices: [voice]);

      expect(settings.getVoiceById('non-existent-id'), isNull);
    });

    test('getServerById returns correct server', () {
      const server1 = OpenClawServer(
        id: 'server-1',
        name: 'Server 1',
        baseUrl: 'http://localhost:3000/v1',
      );
      const server2 = OpenClawServer(
        id: 'server-2',
        name: 'Server 2',
        baseUrl: 'http://localhost:4000/v1',
      );

      const settings = Settings(openclawServers: [server1, server2]);

      expect(settings.getServerById('server-2'), server2);
      expect(settings.getServerById('server-2')?.name, 'Server 2');
    });

    test('getServerById returns null for non-existent ID', () {
      const server = OpenClawServer(
        id: 'server-1',
        name: 'Server 1',
        baseUrl: 'http://localhost:3000/v1',
      );
      const settings = Settings(openclawServers: [server]);

      expect(settings.getServerById('non-existent-id'), isNull);
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
      expect(instance.agentIds, ['main']);
      expect(instance.allowBadCertificate, false);
    });

    test('creates instance with token and agentIds', () {
      const instance = OpenClawInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'http://localhost:3000/v1',
        token: 'test-token',
        sessionId: 'test-session',
        agentIds: ['main', 'elysse'],
      );

      expect(instance.token, 'test-token');
      expect(instance.agentIds, ['main', 'elysse']);
    });

    test('toJson serialises correctly', () {
      const instance = OpenClawInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'http://localhost:3000/v1',
        token: 'test-token',
        sessionId: 'test-session',
        agentIds: ['main', 'elysse'],
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
      expect(json['agentIds'], ['main', 'elysse']);
      expect(json['allowBadCertificate'], false);
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
        'agentIds': ['main', 'alex', 'elysse'],
        'allowBadCertificate': true,
      };

      final instance = OpenClawInstance.fromJson(json);

      expect(instance.id, 'test-id');
      expect(instance.name, 'Test Instance');
      expect(instance.baseUrl, 'http://localhost:3000/v1');
      expect(instance.token, 'test-token');
      expect(instance.sessionId, 'test-session');
      expect(instance.elevenLabsVoice, ElevenLabsVoice.liam);
      expect(instance.elevenLabsSpeed, 1.0);
      expect(instance.agentIds, ['main', 'alex', 'elysse']);
      expect(instance.allowBadCertificate, true);
    });

    test('fromJson handles missing optional fields', () {
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
      expect(instance.agentIds, ['main']);
      expect(instance.allowBadCertificate, false);
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
        agentIds: ['main', 'elysse', 'alex'],
        allowBadCertificate: true,
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
      expect(deserialized.agentIds, original.agentIds);
      expect(deserialized.allowBadCertificate, original.allowBadCertificate);
    });

    test('copyWith creates copy with updated fields', () {
      const original = OpenClawInstance(
        id: 'id-1',
        name: 'Original',
        baseUrl: 'http://old:3000/v1',
        token: 'old-token',
        sessionId: 'session-1',
        agentIds: ['main'],
      );

      final updated = original.copyWith(
        name: 'Updated',
        baseUrl: 'http://new:3000/v1',
        agentIds: ['main', 'elysse'],
      );

      expect(updated.id, 'id-1');
      expect(updated.name, 'Updated');
      expect(updated.baseUrl, 'http://new:3000/v1');
      expect(updated.token, 'old-token');
      expect(updated.sessionId, 'session-1');
      expect(updated.elevenLabsVoice, original.elevenLabsVoice);
      expect(updated.elevenLabsSpeed, original.elevenLabsSpeed);
      expect(updated.agentIds, ['main', 'elysse']);
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

    test('AgentType has expected values', () {
      expect(AgentType.values.length, 3);
      expect(AgentType.values, contains(AgentType.claude));
      expect(AgentType.values, contains(AgentType.openai));
      expect(AgentType.values, contains(AgentType.openclaw));
    });

    test('VoiceProvider has expected values', () {
      expect(VoiceProvider.values.length, 3);
      expect(VoiceProvider.values, contains(VoiceProvider.onDevice));
      expect(VoiceProvider.values, contains(VoiceProvider.elevenlabs));
      expect(VoiceProvider.values, contains(VoiceProvider.openai));
    });
  });
}
