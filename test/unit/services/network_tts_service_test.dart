import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voiceapp/services/elevenlabs_tts_service.dart';
import 'package:voiceapp/services/openai_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Mock the FlutterTts method channel to prevent MissingPluginException
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall methodCall) async {
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      null,
    );
  });

  group('ElevenLabsTtsService', () {
    test('can be instantiated with required parameters', () async {
      final service = ElevenLabsTtsService(
        apiKey: 'test-key',
        voiceId: 'test-voice',
        modelId: 'eleven_turbo_v2_5',
      );

      expect(service, isNotNull);
      expect(service.apiKey, equals('test-key'));
      expect(service.voiceId, equals('test-voice'));
      expect(service.modelId, equals('eleven_turbo_v2_5'));
      await service.dispose();
    });

    test('initialize method completes', () async {
      final service = ElevenLabsTtsService(
        apiKey: 'test-key',
        voiceId: 'test-voice',
        modelId: 'test-model',
      );

      await expectLater(service.initialize(), completes);
      await service.dispose();
    });

    test('dispose can be called without crashing', () async {
      final service = ElevenLabsTtsService(
        apiKey: 'test-key',
        voiceId: 'test-voice',
        modelId: 'test-model',
      );

      await service.dispose();
      expect(true, true);
    });

    test('dispose can be called multiple times', () async {
      final service = ElevenLabsTtsService(
        apiKey: 'test-key',
        voiceId: 'test-voice',
        modelId: 'test-model',
      );

      await service.dispose();
      await service.dispose();
      await service.dispose();
      expect(true, true);
    });

    test('onDone callback can be set', () async {
      final service = ElevenLabsTtsService(
        apiKey: 'test-key',
        voiceId: 'test-voice',
        modelId: 'test-model',
      );

      service.onDone = () {};
      expect(service.onDone, isNotNull);
      await service.dispose();
    });
  });

  group('OpenAITtsService', () {
    test('can be instantiated with required parameters', () async {
      final service = OpenAITtsService(
        apiKey: 'test-key',
        voice: 'alloy',
        model: 'tts-1',
      );

      expect(service, isNotNull);
      expect(service.apiKey, equals('test-key'));
      expect(service.voice, equals('alloy'));
      expect(service.model, equals('tts-1'));
      await service.dispose();
    });

    test('initialize method completes', () async {
      final service = OpenAITtsService(
        apiKey: 'test-key',
        voice: 'alloy',
        model: 'tts-1',
      );

      await expectLater(service.initialize(), completes);
      await service.dispose();
    });

    test('dispose can be called without crashing', () async {
      final service = OpenAITtsService(
        apiKey: 'test-key',
        voice: 'alloy',
        model: 'tts-1',
      );

      await service.dispose();
      expect(true, true);
    });

    test('dispose can be called multiple times', () async {
      final service = OpenAITtsService(
        apiKey: 'test-key',
        voice: 'alloy',
        model: 'tts-1',
      );

      await service.dispose();
      await service.dispose();
      await service.dispose();
      expect(true, true);
    });

    test('onDone callback can be set', () async {
      final service = OpenAITtsService(
        apiKey: 'test-key',
        voice: 'alloy',
        model: 'tts-1',
      );

      service.onDone = () {};
      expect(service.onDone, isNotNull);
      await service.dispose();
    });
  });
}
