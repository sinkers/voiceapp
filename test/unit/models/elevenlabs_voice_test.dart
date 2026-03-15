import 'package:flutter_test/flutter_test.dart';
import 'package:voiceapp/models/elevenlabs_voice.dart';

void main() {
  group('ElevenLabsVoice', () {
    test('has correct voice IDs', () {
      expect(ElevenLabsVoice.rachel.voiceId, equals('21m00Tcm4TlvDq8ikWAM'));
      expect(ElevenLabsVoice.liam.voiceId, equals('TX3LPaxmHKxFdv7VOQHJ'));
    });

    test('has correct labels', () {
      expect(ElevenLabsVoice.rachel.label, equals('Rachel (Female)'));
      expect(ElevenLabsVoice.liam.label, equals('Liam (Male)'));
    });

    test('fromVoiceId returns correct voice for Rachel', () {
      final voice = ElevenLabsVoice.fromVoiceId('21m00Tcm4TlvDq8ikWAM');
      expect(voice, equals(ElevenLabsVoice.rachel));
    });

    test('fromVoiceId returns correct voice for Liam', () {
      final voice = ElevenLabsVoice.fromVoiceId('TX3LPaxmHKxFdv7VOQHJ');
      expect(voice, equals(ElevenLabsVoice.liam));
    });

    test('fromVoiceId returns null for unknown voice ID', () {
      final voice = ElevenLabsVoice.fromVoiceId('unknown-voice-id');
      expect(voice, isNull);
    });

    test('fromVoiceId returns null for empty string', () {
      final voice = ElevenLabsVoice.fromVoiceId('');
      expect(voice, isNull);
    });

    test('all voices have unique IDs', () {
      final ids = ElevenLabsVoice.values.map((v) => v.voiceId).toSet();
      expect(ids.length, equals(ElevenLabsVoice.values.length));
    });

    test('all voices have non-empty labels', () {
      for (final voice in ElevenLabsVoice.values) {
        expect(voice.label.isNotEmpty, isTrue);
      }
    });

    test('all voices have non-empty IDs', () {
      for (final voice in ElevenLabsVoice.values) {
        expect(voice.voiceId.isNotEmpty, isTrue);
      }
    });
  });
}
