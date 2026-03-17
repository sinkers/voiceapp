import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum VoiceProvider { onDevice, elevenlabs, openai }

class VoiceConfig {
  final String id;
  final String name;
  final VoiceProvider provider;
  final String? apiKey; // For elevenlabs/openai
  final String?
      voiceId; // For elevenlabs: voice ID; for openai: voice name (alloy/echo/etc)
  final String? modelId; // For elevenlabs: model ID; for openai: tts-1/tts-1-hd
  final double? rate; // For onDevice only
  final double? pitch; // For onDevice only

  const VoiceConfig({
    required this.id,
    required this.name,
    required this.provider,
    this.apiKey,
    this.voiceId,
    this.modelId,
    this.rate,
    this.pitch,
  });

  /// System (on-device) voice with default settings
  factory VoiceConfig.system({
    double rate = 0.5,
    double pitch = 1.0,
  }) =>
      VoiceConfig(
        id: 'system',
        name: 'System',
        provider: VoiceProvider.onDevice,
        rate: rate,
        pitch: pitch,
      );

  /// ElevenLabs voice
  factory VoiceConfig.elevenlabs({
    required String name,
    required String voiceId,
    String? apiKey,
    String modelId = 'eleven_turbo_v2_5',
  }) =>
      VoiceConfig(
        id: _uuid.v4(),
        name: name,
        provider: VoiceProvider.elevenlabs,
        apiKey: apiKey,
        voiceId: voiceId,
        modelId: modelId,
      );

  /// OpenAI TTS voice
  factory VoiceConfig.openai({
    required String name,
    required String voiceId, // alloy, echo, fable, onyx, nova, shimmer
    String? apiKey,
    String modelId = 'tts-1',
  }) =>
      VoiceConfig(
        id: _uuid.v4(),
        name: name,
        provider: VoiceProvider.openai,
        apiKey: apiKey,
        voiceId: voiceId,
        modelId: modelId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'provider': provider.name,
        if (apiKey != null) 'apiKey': apiKey,
        if (voiceId != null) 'voiceId': voiceId,
        if (modelId != null) 'modelId': modelId,
        if (rate != null) 'rate': rate,
        if (pitch != null) 'pitch': pitch,
      };

  factory VoiceConfig.fromJson(Map<String, dynamic> json) {
    final providerName = json['provider'] as String;
    final provider = VoiceProvider.values.firstWhere(
      (p) => p.name == providerName,
      orElse: () => VoiceProvider.onDevice,
    );

    return VoiceConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      provider: provider,
      apiKey: json['apiKey'] as String?,
      voiceId: json['voiceId'] as String?,
      modelId: json['modelId'] as String?,
      rate: (json['rate'] as num?)?.toDouble(),
      pitch: (json['pitch'] as num?)?.toDouble(),
    );
  }

  VoiceConfig copyWith({
    String? id,
    String? name,
    VoiceProvider? provider,
    String? apiKey,
    String? voiceId,
    String? modelId,
    double? rate,
    double? pitch,
    bool clearApiKey = false,
  }) =>
      VoiceConfig(
        id: id ?? this.id,
        name: name ?? this.name,
        provider: provider ?? this.provider,
        apiKey: clearApiKey ? null : (apiKey ?? this.apiKey),
        voiceId: voiceId ?? this.voiceId,
        modelId: modelId ?? this.modelId,
        rate: rate ?? this.rate,
        pitch: pitch ?? this.pitch,
      );
}
