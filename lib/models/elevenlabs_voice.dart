enum ElevenLabsVoice {
  rachel("Rachel (Female)", "21m00Tcm4TlvDq8ikWAM"),
  liam("Liam (Male)", "TX3LPaxmHKxFdv7VOQHJ");

  const ElevenLabsVoice(this.label, this.voiceId);
  final String label;
  final String voiceId;

  static ElevenLabsVoice? fromVoiceId(String voiceId) {
    for (final voice in ElevenLabsVoice.values) {
      if (voice.voiceId == voiceId) {
        return voice;
      }
    }
    return null;
  }
}
