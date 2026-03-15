import 'package:collection/collection.dart';

enum ElevenLabsVoice {
  rachel("Rachel (Female)", "21m00Tcm4TlvDq8ikWAM"),
  charlotte("Charlotte (Female)", "XB0fDUnXU5powFXDhCwa"),
  liam("Liam (Male)", "TX3LPaxmHKxFdv7VOQHJ"),
  charlie("Charlie (Male)", "IKne3meq5aSn9XLyUdCD");

  const ElevenLabsVoice(this.label, this.voiceId);
  final String label;
  final String voiceId;

  static ElevenLabsVoice? fromVoiceId(String voiceId) {
    return ElevenLabsVoice.values.firstWhereOrNull((v) => v.voiceId == voiceId);
  }
}
