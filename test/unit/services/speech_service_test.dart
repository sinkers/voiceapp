import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:voiceapp/services/speech_service.dart';

/// Hand-crafted fake that avoids platform channels.
/// Only [isListening] and the methods called by [SpeechService] are handled;
/// everything else falls through to [Fake.noSuchMethod] and throws.
class _FakeSpeechToText extends Fake implements SpeechToText {
  @override
  bool get isListening => false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #initialize) return Future<bool>.value(true);
    if (invocation.memberName == #listen ||
        invocation.memberName == #stop ||
        invocation.memberName == #cancel) {
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeechService Double Callback Prevention', () {
    late SpeechService service;

    setUp(() {
      service = SpeechService(stt: _FakeSpeechToText());
    });

    test(
        'onStopped fires only once when both notListening and done are received',
        () async {
      await service.initialize();

      int callCount = 0;
      service.onStopped = () => callCount++;

      await service.startListening();

      // Simulate speech_to_text firing both status strings for the same session
      service.triggerStatusForTesting('notListening');
      service.triggerStatusForTesting('done');

      expect(callCount, equals(1));
    });

    test('_hasReportedStop is reset when startListening is called', () async {
      await service.initialize();
      service.onStopped = () {};

      await service.startListening();
      expect(service.hasReportedStopForTesting, isFalse);

      // Trigger a stop — flag becomes true
      service.triggerStatusForTesting('notListening');
      expect(service.hasReportedStopForTesting, isTrue);

      // New session resets the flag
      await service.startListening();
      expect(service.hasReportedStopForTesting, isFalse);
    });

    test('service can be initialized and listening started', () async {
      final initialized = await service.initialize();
      expect(initialized, isTrue);

      await service.startListening();
      expect(() => service.stopListening(), returnsNormally);
    });

    test('callbacks can be set and unset', () async {
      await service.initialize();

      service.onStopped = () {};
      service.onFinalResult = (text) {};
      service.onPartialResult = (text) {};

      expect(service.onStopped, isNotNull);
      expect(service.onFinalResult, isNotNull);
      expect(service.onPartialResult, isNotNull);

      service.onStopped = null;
      service.onFinalResult = null;
      service.onPartialResult = null;

      expect(service.onStopped, isNull);
      expect(service.onFinalResult, isNull);
      expect(service.onPartialResult, isNull);
    });

    test('dispose can be called safely', () async {
      await service.initialize();
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
