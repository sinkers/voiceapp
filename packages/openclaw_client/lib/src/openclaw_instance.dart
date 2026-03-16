import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Connection configuration for an OpenClaw gateway instance.
class OpenClawInstance {
  final String id;
  final String name;
  final String baseUrl;
  final String token;
  final String sessionId;

  /// ElevenLabs voice ID to use for TTS with this instance.
  final String elevenLabsVoiceId;

  /// ElevenLabs speech speed multiplier for this instance.
  final double elevenLabsSpeed;

  /// Agent IDs available on this instance (cached after discovery).
  final List<String> agentIds;

  /// Whether to allow self-signed / invalid TLS certificates.
  final bool allowBadCertificate;

  const OpenClawInstance({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.token = '',
    required this.sessionId,
    this.elevenLabsVoiceId = '21m00Tcm4TlvDq8ikWAM',
    this.elevenLabsSpeed = 1.1,
    this.agentIds = const ['main'],
    this.allowBadCertificate = false,
  });

  // TODO(security): token should be moved to flutter_secure_storage
  // and excluded from serialization.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'token': token,
    'sessionId': sessionId,
    'elevenLabsVoiceId': elevenLabsVoiceId,
    'elevenLabsSpeed': elevenLabsSpeed,
    'agentIds': agentIds,
    'allowBadCertificate': allowBadCertificate,
  };

  factory OpenClawInstance.fromJson(Map<String, dynamic> json) =>
      OpenClawInstance(
        id: json['id'] as String,
        name: json['name'] as String,
        baseUrl: json['baseUrl'] as String,
        token: (json['token'] as String?) ?? '',
        sessionId: json['sessionId'] as String? ?? _uuid.v4(),
        elevenLabsVoiceId:
            json['elevenLabsVoiceId'] as String? ?? '21m00Tcm4TlvDq8ikWAM',
        elevenLabsSpeed: (json['elevenLabsSpeed'] as num?)?.toDouble() ?? 1.1,
        agentIds:
            (json['agentIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const ['main'],
        allowBadCertificate: (json['allowBadCertificate'] as bool?) ?? false,
      );

  OpenClawInstance copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? token,
    String? sessionId,
    String? elevenLabsVoiceId,
    double? elevenLabsSpeed,
    List<String>? agentIds,
    bool? allowBadCertificate,
  }) => OpenClawInstance(
    id: id ?? this.id,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    token: token ?? this.token,
    sessionId: sessionId ?? this.sessionId,
    elevenLabsVoiceId: elevenLabsVoiceId ?? this.elevenLabsVoiceId,
    elevenLabsSpeed: elevenLabsSpeed ?? this.elevenLabsSpeed,
    agentIds: agentIds ?? this.agentIds,
    allowBadCertificate: allowBadCertificate ?? this.allowBadCertificate,
  );
}
