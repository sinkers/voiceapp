import 'package:flutter_test/flutter_test.dart';
import 'package:voiceapp/models/voice_config.dart';

void main() {
  group('VoiceConfig.system', () {
    test('creates on-device voice with default settings', () {
      final voice = VoiceConfig.system();

      expect(voice.id, 'system');
      expect(voice.name, 'System');
      expect(voice.provider, VoiceProvider.onDevice);
      expect(voice.rate, 0.5);
      expect(voice.pitch, 1.0);
    });

    test('creates on-device voice with custom settings', () {
      final voice = VoiceConfig.system(rate: 0.7, pitch: 1.2);

      expect(voice.rate, 0.7);
      expect(voice.pitch, 1.2);
    });
  });

  group('VoiceConfig.elevenlabs', () {
    test('creates ElevenLabs voice with required fields', () {
      final voice = VoiceConfig.elevenlabs(
        name: 'Rachel',
        voiceId: '21m00Tcm4TlvDq8ikWAM',
      );

      expect(voice.name, 'Rachel');
      expect(voice.provider, VoiceProvider.elevenlabs);
      expect(voice.voiceId, '21m00Tcm4TlvDq8ikWAM');
      expect(voice.modelId, 'eleven_turbo_v2_5');
      expect(voice.id, isNotEmpty);
    });

    test('creates ElevenLabs voice with custom modelId', () {
      final voice = VoiceConfig.elevenlabs(
        name: 'Rachel',
        voiceId: '21m00Tcm4TlvDq8ikWAM',
        modelId: 'eleven_monolingual_v1',
      );

      expect(voice.modelId, 'eleven_monolingual_v1');
    });
  });

  group('VoiceConfig.openai', () {
    test('creates OpenAI TTS voice with required fields', () {
      final voice = VoiceConfig.openai(
        name: 'Alloy',
        voiceId: 'alloy',
      );

      expect(voice.name, 'Alloy');
      expect(voice.provider, VoiceProvider.openai);
      expect(voice.voiceId, 'alloy');
      expect(voice.modelId, 'tts-1');
      expect(voice.id, isNotEmpty);
    });

    test('creates OpenAI TTS voice with custom modelId', () {
      final voice = VoiceConfig.openai(
        name: 'Alloy',
        voiceId: 'alloy',
        modelId: 'tts-1-hd',
      );

      expect(voice.modelId, 'tts-1-hd');
    });
  });

  group('VoiceConfig serialization', () {
    test('on-device voice toJson/fromJson round-trip', () {
      final original = VoiceConfig.system(rate: 0.6, pitch: 1.1);

      final json = original.toJson();
      final restored = VoiceConfig.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.provider, VoiceProvider.onDevice);
      expect(restored.rate, original.rate);
      expect(restored.pitch, original.pitch);
    });

    test('ElevenLabs voice toJson/fromJson round-trip', () {
      final original = VoiceConfig.elevenlabs(
        name: 'Rachel',
        voiceId: '21m00Tcm4TlvDq8ikWAM',
        apiKey: 'test-key',
        modelId: 'eleven_turbo_v2_5',
      );

      final json = original.toJson();
      final restored = VoiceConfig.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.provider, VoiceProvider.elevenlabs);
      expect(restored.voiceId, original.voiceId);
      expect(restored.apiKey, original.apiKey);
      expect(restored.modelId, original.modelId);
    });

    test('OpenAI voice toJson/fromJson round-trip', () {
      final original = VoiceConfig.openai(
        name: 'Alloy',
        voiceId: 'alloy',
        apiKey: 'test-key',
        modelId: 'tts-1-hd',
      );

      final json = original.toJson();
      final restored = VoiceConfig.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.provider, VoiceProvider.openai);
      expect(restored.voiceId, original.voiceId);
      expect(restored.apiKey, original.apiKey);
      expect(restored.modelId, original.modelId);
    });
  });

  group('VoiceConfig.copyWith', () {
    test('preserves unchanged values', () {
      final original = VoiceConfig.elevenlabs(
        name: 'Rachel',
        voiceId: '21m00Tcm4TlvDq8ikWAM',
        apiKey: 'key-1',
      );

      final copy = original.copyWith(name: 'Updated Rachel');

      expect(copy.name, 'Updated Rachel');
      expect(copy.provider, original.provider);
      expect(copy.voiceId, original.voiceId);
      expect(copy.apiKey, original.apiKey);
      expect(copy.id, original.id);
    });

    test('can clear apiKey', () {
      final original = VoiceConfig.elevenlabs(
        name: 'Rachel',
        voiceId: '21m00Tcm4TlvDq8ikWAM',
        apiKey: 'key-1',
      );

      final copy = original.copyWith(clearApiKey: true);

      expect(copy.apiKey, isNull);
      expect(copy.name, original.name);
    });
  });

  group('VoiceConfig.fromJson error handling', () {
    test('throws FormatException for unknown voice provider', () {
      final json = {
        'id': 'voice-1',
        'name': 'Test Voice',
        'provider': 'unknown_provider',
      };

      expect(
        () => VoiceConfig.fromJson(json),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Unknown VoiceProvider: unknown_provider'),
        )),
      );
    });
  });
}
