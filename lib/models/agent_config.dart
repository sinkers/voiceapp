import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum AgentType { claude, openai, openclaw }

class OpenClawServer {
  final String id;
  final String name;
  final String baseUrl;
  final String? token;
  final bool allowBadCertificate;
  final String sessionId;

  OpenClawServer({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.token,
    this.allowBadCertificate = false,
    String? sessionId,
  }) : sessionId = sessionId ?? _uuid.v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        // token excluded - stored in secure storage
        'allowBadCertificate': allowBadCertificate,
        'sessionId': sessionId,
      };

  factory OpenClawServer.fromJson(Map<String, dynamic> json) => OpenClawServer(
        id: json['id'] as String,
        name: json['name'] as String,
        baseUrl: json['baseUrl'] as String,
        token: json['token'] as String?, // may be set from secure storage
        allowBadCertificate: (json['allowBadCertificate'] as bool?) ?? false,
        sessionId: json['sessionId'] as String?,
      );

  OpenClawServer copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? token,
    bool? allowBadCertificate,
    bool clearToken = false,
    String? sessionId,
  }) =>
      OpenClawServer(
        id: id ?? this.id,
        name: name ?? this.name,
        baseUrl: baseUrl ?? this.baseUrl,
        token: clearToken ? null : (token ?? this.token),
        allowBadCertificate: allowBadCertificate ?? this.allowBadCertificate,
        sessionId: sessionId ?? this.sessionId,
      );
}

class AgentConfig {
  final String id;
  final String name;
  final AgentType type;
  final String? apiKey; // For Claude and OpenAI
  final String? model; // For Claude and OpenAI
  final String? baseUrl; // For OpenAI
  final String? serverId; // For OpenClaw: reference to OpenClawServer
  final String? agentName; // For OpenClaw: the agent name/ID on the server
  final String voiceId; // Reference to VoiceConfig.id

  const AgentConfig({
    required this.id,
    required this.name,
    required this.type,
    this.apiKey,
    this.model,
    this.baseUrl,
    this.serverId,
    this.agentName,
    required this.voiceId,
  });

  String get displayName => name;

  String get providerLabel {
    switch (type) {
      case AgentType.claude:
        return 'Anthropic';
      case AgentType.openai:
        return 'OpenAI';
      case AgentType.openclaw:
        return 'OpenClaw';
    }
  }

  /// Claude agent
  factory AgentConfig.claude({
    required String name,
    required String apiKey,
    required String voiceId,
    String model = 'claude-opus-4-6',
  }) =>
      AgentConfig(
        id: _uuid.v4(),
        name: name,
        type: AgentType.claude,
        apiKey: apiKey,
        model: model,
        voiceId: voiceId,
      );

  /// OpenAI agent
  factory AgentConfig.openai({
    required String name,
    required String apiKey,
    required String voiceId,
    String model = 'gpt-4o',
    String baseUrl = 'https://api.openai.com/v1',
  }) =>
      AgentConfig(
        id: _uuid.v4(),
        name: name,
        type: AgentType.openai,
        apiKey: apiKey,
        model: model,
        baseUrl: baseUrl,
        voiceId: voiceId,
      );

  /// OpenClaw agent
  factory AgentConfig.openclaw({
    required String name,
    required String serverId,
    required String agentName,
    required String voiceId,
  }) =>
      AgentConfig(
        id: _uuid.v4(),
        name: name,
        type: AgentType.openclaw,
        serverId: serverId,
        agentName: agentName,
        voiceId: voiceId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        if (apiKey != null) 'apiKey': apiKey,
        if (model != null) 'model': model,
        if (baseUrl != null) 'baseUrl': baseUrl,
        if (serverId != null) 'serverId': serverId,
        if (agentName != null) 'agentName': agentName,
        'voiceId': voiceId,
      };

  factory AgentConfig.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String;
    final type = AgentType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => throw FormatException('Unknown AgentType: $typeName'),
    );

    return AgentConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      type: type,
      apiKey: json['apiKey'] as String?,
      model: json['model'] as String?,
      baseUrl: json['baseUrl'] as String?,
      serverId: json['serverId'] as String?,
      agentName: json['agentName'] as String?,
      voiceId: json['voiceId'] as String,
    );
  }

  AgentConfig copyWith({
    String? id,
    String? name,
    AgentType? type,
    String? apiKey,
    String? model,
    String? baseUrl,
    String? serverId,
    String? agentName,
    String? voiceId,
    bool clearApiKey = false,
    bool clearModel = false,
    bool clearBaseUrl = false,
    bool clearServerId = false,
    bool clearAgentName = false,
  }) =>
      AgentConfig(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        apiKey: clearApiKey ? null : (apiKey ?? this.apiKey),
        model: clearModel ? null : (model ?? this.model),
        baseUrl: clearBaseUrl ? null : (baseUrl ?? this.baseUrl),
        serverId: clearServerId ? null : (serverId ?? this.serverId),
        agentName: clearAgentName ? null : (agentName ?? this.agentName),
        voiceId: voiceId ?? this.voiceId,
      );
}
