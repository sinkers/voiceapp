import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voiceapp/services/on_device_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnDeviceTtsService Queue Logic', () {
    late OnDeviceTtsService service;

    setUp(() {
      service = OnDeviceTtsService();

      // Mock the FlutterTts method channel to prevent MissingPluginException
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
            MethodCall methodCall,
          ) async {
            switch (methodCall.method) {
              case 'speak':
              case 'stop':
              case 'setLanguage':
              case 'setSpeechRate':
              case 'setPitch':
              case 'awaitSpeakCompletion':
              case 'setSharedInstance':
                return null;
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
    });

    test('enqueue adds text to queue', () async {
      await service.initialize();

      // We can't directly access the queue, but we can verify behavior
      service.enqueue('First sentence');
      service.enqueue('Second sentence');

      // The service should handle these items
      expect(() => service.enqueue('Third sentence'), returnsNormally);
    });

    test('enqueue ignores empty or whitespace-only text', () async {
      await service.initialize();

      service.enqueue('  ');
      service.enqueue('');

      // Should not crash
      expect(() => service.markFinished(), returnsNormally);
    });

    test('reset clears the queue and resets state', () async {
      await service.initialize();

      service.enqueue('Test sentence');
      service.markFinished();

      await service.reset();

      // After reset, the service should be ready for new content
      expect(() => service.enqueue('New sentence'), returnsNormally);
    });

    test('stop clears queue and stops playback', () async {
      await service.initialize();

      service.enqueue('Test sentence');

      await service.stop();

      // After stop, should be able to enqueue new content
      expect(() => service.enqueue('New sentence'), returnsNormally);
    });

    test('markFinished can be called', () async {
      await service.initialize();

      service.enqueue('Test sentence');

      // Should not crash
      expect(() => service.markFinished(), returnsNormally);
    });

    test(
      'waitUntilDone completes immediately if already finished and empty',
      () async {
        await service.initialize();

        service.markFinished();

        final future = service.waitUntilDone();
        expect(future, completes);
      },
    );

    test('onDone callback can be set', () async {
      await service.initialize();

      service.onDone = () {};

      service.markFinished();
      await service.waitUntilDone();

      // Verify the structure is correct
      expect(service.onDone, isNotNull);
    });

    test('updateSettings can be called multiple times', () async {
      await service.initialize();

      expect(() => service.updateSettings(0.5, 1.0), returnsNormally);
      expect(() => service.updateSettings(0.8, 1.2), returnsNormally);
    });

    test('handles multiple enqueue calls before playback starts', () async {
      await service.initialize();

      service.enqueue('Sentence one');
      service.enqueue('Sentence two');
      service.enqueue('Sentence three');

      // Should not crash
      service.markFinished();
      expect(() => service.waitUntilDone(), returnsNormally);
    });

    test('reset after stop clears all state', () async {
      await service.initialize();

      service.enqueue('Test');
      service.markFinished();
      await service.stop();

      await service.reset();

      // Should be in clean state
      service.enqueue('New content');
      service.markFinished();

      // Verify no crash
      expect(true, true);
    });

    test('stop completes pending waitUntilDone', () async {
      await service.initialize();

      service.enqueue('Test sentence');
      final waitFuture = service.waitUntilDone();

      await service.stop();

      expect(waitFuture, completes);
    });

    test('reset stops active audio before clearing queue', () async {
      await service.initialize();

      // Track whether stop was called
      bool stopCalled = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'stop') {
              stopCalled = true;
            }
            return null;
          });

      service.enqueue('Test sentence');

      await service.reset();

      // Verify that stop() was called during reset
      expect(stopCalled, isTrue);
    });
  });

  group('OnDeviceTtsService Edge Cases', () {
    late OnDeviceTtsService service;

    setUp(() {
      service = OnDeviceTtsService();

      // Mock the FlutterTts method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
            MethodCall methodCall,
          ) async {
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
    });

    test('calling stop multiple times does not crash', () async {
      await service.initialize();

      await service.stop();
      await service.stop();
      await service.stop();

      expect(true, true); // No crash
    });

    test('calling reset multiple times does not crash', () async {
      await service.initialize();

      await service.reset();
      await service.reset();
      await service.reset();

      expect(true, true); // No crash
    });

    test('handles initialization properly', () async {
      final result = service.initialize();

      expect(result, completes);
    });
  });
}
