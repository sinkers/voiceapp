import 'package:flutter_test/flutter_test.dart';
import 'package:voiceapp/models/agent_config.dart';
import 'package:voiceapp/models/settings.dart';

void main() {
  group('allAgents', () {
    test('returns two direct model agents when no OpenClaw instances', () {
      const settings = Settings(
        claudeModelName: 'claude-opus-4-6',
        openaiModelName: 'gpt-4o',
      );

      final agents = settings.allAgents;

      expect(agents.length, 2);
      expect(agents[0], isA<DirectModelAgentConfig>());
      expect(agents[1], isA<DirectModelAgentConfig>());

      final claude = agents[0] as DirectModelAgentConfig;
      expect(claude.backend, LLMBackend.claude);
      expect(claude.modelName, 'claude-opus-4-6');
      expect(claude.displayName, 'claude-opus-4-6');
      expect(claude.providerLabel, 'Anthropic');
      expect(claude.id, 'claude:claude-opus-4-6');

      final openai = agents[1] as DirectModelAgentConfig;
      expect(openai.backend, LLMBackend.openaiCompatible);
      expect(openai.modelName, 'gpt-4o');
      expect(openai.providerLabel, 'OpenAI');
      expect(openai.id, 'openaiCompatible:gpt-4o');
    });

    test('includes one OpenClawAgentConfig per agent per instance', () {
      const instance1 = OpenClawInstance(
        id: 'inst-1',
        name: 'Pi Home',
        baseUrl: 'http://10.0.0.1:18789/v1',
        sessionId: 'ses-1',
        agentIds: ['main'], // default
      );
      const instance2 = OpenClawInstance(
        id: 'inst-2',
        name: 'Pi Work',
        baseUrl: 'http://10.0.0.2:18789/v1',
        sessionId: 'ses-2',
        agentIds: ['main'], // default
      );

      const settings = Settings(
        openclawInstances: [instance1, instance2],
      );

      final agents = settings.allAgents;

      // 2 OpenClaw (1 agent each) + 2 direct
      expect(agents.length, 4);
      expect(agents[0], isA<OpenClawAgentConfig>());
      expect(agents[1], isA<OpenClawAgentConfig>());

      final oc1 = agents[0] as OpenClawAgentConfig;
      expect(oc1.instance.id, 'inst-1');
      expect(oc1.agentId, 'main');
      expect(oc1.displayName, 'main');
      expect(oc1.providerLabel, 'OpenClaw · Pi Home');
      expect(oc1.id, 'openclaw:inst-1:main');

      final oc2 = agents[1] as OpenClawAgentConfig;
      expect(oc2.instance.id, 'inst-2');
      expect(oc2.agentId, 'main');
    });

    test('expands instance with multiple agents into multiple configs', () {
      const instance = OpenClawInstance(
        id: 'inst-1',
        name: 'Pi',
        baseUrl: 'http://10.0.0.1/v1',
        sessionId: 'ses-1',
        agentIds: ['main', 'assistant', 'helper'],
      );

      const settings = Settings(
        openclawInstances: [instance],
      );

      final agents = settings.allAgents;

      // 3 OpenClaw agents + 2 direct = 5
      expect(agents.length, 5);

      final oc1 = agents[0] as OpenClawAgentConfig;
      expect(oc1.agentId, 'main');
      expect(oc1.id, 'openclaw:inst-1:main');

      final oc2 = agents[1] as OpenClawAgentConfig;
      expect(oc2.agentId, 'assistant');
      expect(oc2.id, 'openclaw:inst-1:assistant');

      final oc3 = agents[2] as OpenClawAgentConfig;
      expect(oc3.agentId, 'helper');
      expect(oc3.id, 'openclaw:inst-1:helper');
    });

    test('each instance expands based on its agentIds list', () {
      const instance1 = OpenClawInstance(
        id: 'inst-1',
        name: 'Pi 1',
        baseUrl: 'http://10.0.0.1/v1',
        sessionId: 'ses-1',
        agentIds: ['main', 'custom-agent'],
      );
      const instance2 = OpenClawInstance(
        id: 'inst-2',
        name: 'Pi 2',
        baseUrl: 'http://10.0.0.2/v1',
        sessionId: 'ses-2',
        agentIds: ['main'],
      );

      const settings = Settings(
        openclawInstances: [instance1, instance2],
      );

      final agents = settings.allAgents;

      // 3 OpenClaw (2 from inst-1, 1 from inst-2) + 2 direct = 5
      expect(agents.length, 5);

      final oc1 = agents[0] as OpenClawAgentConfig;
      expect(oc1.instance.id, 'inst-1');
      expect(oc1.agentId, 'main');

      final oc2 = agents[1] as OpenClawAgentConfig;
      expect(oc2.instance.id, 'inst-1');
      expect(oc2.agentId, 'custom-agent');

      final oc3 = agents[2] as OpenClawAgentConfig;
      expect(oc3.instance.id, 'inst-2');
      expect(oc3.agentId, 'main');
    });
  });

  group('OpenClawAgentConfig', () {
    test('id is stable and unique', () {
      const instance = OpenClawInstance(
        id: 'inst-1',
        name: 'Pi',
        baseUrl: 'http://10.0.0.1/v1',
        sessionId: 'ses-1',
      );
      const a = OpenClawAgentConfig(instance: instance, agentId: 'main');
      const b = OpenClawAgentConfig(instance: instance, agentId: 'assistant');

      expect(a.id, 'openclaw:inst-1:main');
      expect(b.id, 'openclaw:inst-1:assistant');
      expect(a.id, isNot(equals(b.id)));
    });
  });

  group('DirectModelAgentConfig', () {
    test('id format is backend:modelName', () {
      const c = DirectModelAgentConfig(
          backend: LLMBackend.claude, modelName: 'claude-opus-4-6');
      const o = DirectModelAgentConfig(
          backend: LLMBackend.openaiCompatible, modelName: 'gpt-4o');

      expect(c.id, 'claude:claude-opus-4-6');
      expect(o.id, 'openaiCompatible:gpt-4o');
    });
  });
}
