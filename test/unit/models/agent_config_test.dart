import 'package:flutter_test/flutter_test.dart';
import 'package:voiceapp/models/agent_config.dart';

void main() {
  group('AgentConfig.claude', () {
    test('creates Claude agent with correct properties', () {
      final agent = AgentConfig.claude(
        name: 'My Claude',
        apiKey: 'test-key',
        voiceId: 'voice-1',
        model: 'claude-opus-4-6',
      );

      expect(agent.name, 'My Claude');
      expect(agent.type, AgentType.claude);
      expect(agent.apiKey, 'test-key');
      expect(agent.model, 'claude-opus-4-6');
      expect(agent.voiceId, 'voice-1');
      expect(agent.displayName, 'My Claude');
      expect(agent.providerLabel, 'Anthropic');
      expect(agent.id, isNotEmpty);
    });

    test('uses default model when not specified', () {
      final agent = AgentConfig.claude(
        name: 'Claude',
        apiKey: 'key',
        voiceId: 'voice-1',
      );

      expect(agent.model, 'claude-opus-4-6');
    });
  });

  group('AgentConfig.openai', () {
    test('creates OpenAI agent with correct properties', () {
      final agent = AgentConfig.openai(
        name: 'My GPT',
        apiKey: 'test-key',
        voiceId: 'voice-1',
        model: 'gpt-4o',
        baseUrl: 'https://api.openai.com/v1',
      );

      expect(agent.name, 'My GPT');
      expect(agent.type, AgentType.openai);
      expect(agent.apiKey, 'test-key');
      expect(agent.model, 'gpt-4o');
      expect(agent.baseUrl, 'https://api.openai.com/v1');
      expect(agent.voiceId, 'voice-1');
      expect(agent.displayName, 'My GPT');
      expect(agent.providerLabel, 'OpenAI');
      expect(agent.id, isNotEmpty);
    });

    test('uses default model and baseUrl when not specified', () {
      final agent = AgentConfig.openai(
        name: 'GPT',
        apiKey: 'key',
        voiceId: 'voice-1',
      );

      expect(agent.model, 'gpt-4o');
      expect(agent.baseUrl, 'https://api.openai.com/v1');
    });
  });

  group('AgentConfig.openclaw', () {
    test('creates OpenClaw agent with correct properties', () {
      final agent = AgentConfig.openclaw(
        name: 'My Agent',
        serverId: 'server-1',
        agentName: 'main',
        voiceId: 'voice-1',
      );

      expect(agent.name, 'My Agent');
      expect(agent.type, AgentType.openclaw);
      expect(agent.serverId, 'server-1');
      expect(agent.agentName, 'main');
      expect(agent.voiceId, 'voice-1');
      expect(agent.displayName, 'My Agent');
      expect(agent.providerLabel, 'OpenClaw');
      expect(agent.id, isNotEmpty);
      expect(agent.apiKey, isNull);
      expect(agent.model, isNull);
      expect(agent.baseUrl, isNull);
    });
  });

  group('AgentConfig serialization', () {
    test('Claude agent toJson/fromJson round-trip', () {
      final original = AgentConfig.claude(
        name: 'Claude Agent',
        apiKey: 'test-key',
        voiceId: 'voice-1',
        model: 'claude-opus-4-6',
      );

      final json = original.toJson();
      final restored = AgentConfig.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.type, AgentType.claude);
      expect(restored.apiKey, original.apiKey);
      expect(restored.model, original.model);
      expect(restored.voiceId, original.voiceId);
    });

    test('OpenAI agent toJson/fromJson round-trip', () {
      final original = AgentConfig.openai(
        name: 'OpenAI Agent',
        apiKey: 'test-key',
        voiceId: 'voice-1',
        model: 'gpt-4o',
        baseUrl: 'https://custom.api.com/v1',
      );

      final json = original.toJson();
      final restored = AgentConfig.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.type, AgentType.openai);
      expect(restored.apiKey, original.apiKey);
      expect(restored.model, original.model);
      expect(restored.baseUrl, original.baseUrl);
      expect(restored.voiceId, original.voiceId);
    });

    test('OpenClaw agent toJson/fromJson round-trip', () {
      final original = AgentConfig.openclaw(
        name: 'OpenClaw Agent',
        serverId: 'server-1',
        agentName: 'main',
        voiceId: 'voice-1',
      );

      final json = original.toJson();
      final restored = AgentConfig.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.type, AgentType.openclaw);
      expect(restored.serverId, original.serverId);
      expect(restored.agentName, original.agentName);
      expect(restored.voiceId, original.voiceId);
    });
  });

  group('AgentConfig.copyWith', () {
    test('preserves unchanged values', () {
      final original = AgentConfig.claude(
        name: 'Original',
        apiKey: 'key-1',
        voiceId: 'voice-1',
        model: 'claude-opus-4-6',
      );

      final copy = original.copyWith(name: 'Updated');

      expect(copy.name, 'Updated');
      expect(copy.type, original.type);
      expect(copy.apiKey, original.apiKey);
      expect(copy.model, original.model);
      expect(copy.voiceId, original.voiceId);
      expect(copy.id, original.id);
    });

    test('can clear nullable fields', () {
      final original = AgentConfig.claude(
        name: 'Agent',
        apiKey: 'key-1',
        voiceId: 'voice-1',
        model: 'claude-opus-4-6',
      );

      final copy = original.copyWith(clearApiKey: true, clearModel: true);

      expect(copy.apiKey, isNull);
      expect(copy.model, isNull);
      expect(copy.name, original.name);
    });
  });

  group('OpenClawServer', () {
    test('creates server with required fields', () {
      final server = OpenClawServer(
        id: 'server-1',
        name: 'Test Server',
        baseUrl: 'http://localhost:3000/v1',
      );

      expect(server.id, 'server-1');
      expect(server.name, 'Test Server');
      expect(server.baseUrl, 'http://localhost:3000/v1');
      expect(server.token, isNull);
      expect(server.allowBadCertificate, false);
      expect(server.sessionId, isNotEmpty); // Generated automatically
    });

    test('generates unique sessionId when not provided', () {
      final server1 = OpenClawServer(
        id: 'server-1',
        name: 'Server 1',
        baseUrl: 'http://localhost:3000/v1',
      );
      final server2 = OpenClawServer(
        id: 'server-2',
        name: 'Server 2',
        baseUrl: 'http://localhost:3000/v1',
      );

      expect(server1.sessionId, isNotEmpty);
      expect(server2.sessionId, isNotEmpty);
      expect(server1.sessionId, isNot(equals(server2.sessionId)));
    });

    test('preserves provided sessionId', () {
      final server = OpenClawServer(
        id: 'server-1',
        name: 'Test Server',
        baseUrl: 'http://localhost:3000/v1',
        sessionId: 'my-custom-session-id',
      );

      expect(server.sessionId, 'my-custom-session-id');
    });

    test('toJson excludes token but includes sessionId', () {
      final server = OpenClawServer(
        id: 'server-1',
        name: 'Test',
        baseUrl: 'http://localhost/v1',
        token: 'secret-token',
        sessionId: 'test-session-id',
      );

      final json = server.toJson();

      expect(json['id'], 'server-1');
      expect(json['name'], 'Test');
      expect(json['baseUrl'], 'http://localhost/v1');
      expect(json.containsKey('token'), isFalse);
      expect(json['allowBadCertificate'], false);
      expect(json['sessionId'], 'test-session-id');
    });

    test('fromJson/toJson round-trip', () {
      final original = OpenClawServer(
        id: 'server-1',
        name: 'Test Server',
        baseUrl: 'http://localhost/v1',
        allowBadCertificate: true,
        sessionId: 'test-session-id',
      );

      final json = original.toJson();
      final restored = OpenClawServer.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.baseUrl, original.baseUrl);
      expect(restored.allowBadCertificate, original.allowBadCertificate);
      expect(restored.sessionId, original.sessionId);
    });

    test('copyWith updates fields', () {
      final original = OpenClawServer(
        id: 'server-1',
        name: 'Original',
        baseUrl: 'http://old/v1',
        token: 'token-1',
        sessionId: 'original-session-id',
      );

      final updated = original.copyWith(
        name: 'Updated',
        baseUrl: 'http://new/v1',
      );

      expect(updated.name, 'Updated');
      expect(updated.baseUrl, 'http://new/v1');
      expect(updated.id, original.id);
      expect(updated.token, original.token);
      expect(updated.sessionId, original.sessionId); // Preserved
    });

    test('copyWith can update sessionId', () {
      final original = OpenClawServer(
        id: 'server-1',
        name: 'Server',
        baseUrl: 'http://localhost/v1',
        sessionId: 'old-session-id',
      );

      final updated = original.copyWith(sessionId: 'new-session-id');

      expect(updated.sessionId, 'new-session-id');
      expect(updated.name, original.name);
    });

    test('copyWith can clear token', () {
      final original = OpenClawServer(
        id: 'server-1',
        name: 'Server',
        baseUrl: 'http://localhost/v1',
        token: 'token-1',
      );

      final updated = original.copyWith(clearToken: true);

      expect(updated.token, isNull);
      expect(updated.name, original.name);
    });
  });

  group('AgentConfig.fromJson error handling', () {
    test('throws FormatException for unknown agent type', () {
      final json = {
        'id': 'agent-1',
        'name': 'Test Agent',
        'type': 'unknown_type',
        'voiceId': 'voice-1',
      };

      expect(
        () => AgentConfig.fromJson(json),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Unknown AgentType: unknown_type'),
        )),
      );
    });
  });
}
