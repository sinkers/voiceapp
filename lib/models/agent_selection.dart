import 'settings.dart';

sealed class AgentSelection {
  const AgentSelection();
  String get id;
  String get displayName;
  String get providerLabel;
}

class OpenClawAgentSelection extends AgentSelection {
  final OpenClawInstance instance;
  final String agentId;

  const OpenClawAgentSelection({
    required this.instance,
    required this.agentId,
  });

  @override
  String get id => 'openclaw:${instance.id}:$agentId';

  @override
  String get displayName => agentId;

  @override
  String get providerLabel => 'OpenClaw · ${instance.name}';
}

class DirectModelAgentSelection extends AgentSelection {
  final LLMBackend backend;
  final String modelName;

  const DirectModelAgentSelection({
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
