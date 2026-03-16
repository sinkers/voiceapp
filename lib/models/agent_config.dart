import 'settings.dart';

sealed class AgentConfig {
  const AgentConfig();
  String get id;
  String get displayName;
  String get providerLabel;
}

class OpenClawAgentConfig extends AgentConfig {
  final OpenClawInstance instance;
  final String agentId;

  const OpenClawAgentConfig({required this.instance, required this.agentId});

  @override
  String get id => 'openclaw:${instance.id}:$agentId';

  @override
  String get displayName => agentId;

  @override
  String get providerLabel => 'OpenClaw · ${instance.name}';
}

class DirectModelAgentConfig extends AgentConfig {
  final LLMBackend backend;
  final String modelName;

  const DirectModelAgentConfig({
    required this.backend,
    required this.modelName,
  });

  @override
  String get id => '${backend.name}:$modelName';

  @override
  String get displayName => modelName;

  @override
  String get providerLabel =>
      backend == LLMBackend.claude ? 'Anthropic' : 'OpenAI';
}
