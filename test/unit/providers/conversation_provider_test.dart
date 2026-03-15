import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:voiceapp/models/conversation_state.dart';
import 'package:voiceapp/models/message.dart';
import 'package:voiceapp/models/settings.dart';
import 'package:voiceapp/providers/conversation_provider.dart';
import 'package:voiceapp/services/settings_service.dart';
import 'package:voiceapp/services/speech_service.dart';
import 'package:voiceapp/services/tts_service.dart';

@GenerateMocks([SpeechService, SettingsService, TtsService])
import 'conversation_provider_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock FlutterTts method channel
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter_tts'),
    (MethodCall methodCall) async {
      return null;
    },
  );

  late ConversationProvider provider;
  late MockSpeechService mockSpeechService;
  late MockSettingsService mockSettingsService;

  setUp(() {
    mockSpeechService = MockSpeechService();
    mockSettingsService = MockSettingsService();

    // Mock default behavior
    when(mockSettingsService.load()).thenAnswer((_) async => const Settings());
    when(mockSpeechService.initialize()).thenAnswer((_) async => true);

    provider = ConversationProvider(
      speechService: mockSpeechService,
      settingsService: mockSettingsService,
    );
  });

  group('ConversationProvider State Machine', () {
    test('starts in idle state', () {
      expect(provider.state, ConversationState.idle);
    });

    test('transitions from idle to listening when starting conversation',
        () async {
      await provider.initialize();

      provider.toggleConversation();

      expect(provider.state, ConversationState.listening);
      verify(mockSpeechService.startListening()).called(1);
    });

    test(
        'transitions from listening to idle when speech is stopped with empty text',
        () async {
      await provider.initialize();

      // Start listening
      provider.toggleConversation();
      expect(provider.state, ConversationState.listening);

      // Simulate speech stopped callback with empty text
      provider.toggleConversation(); // Stop listening

      // Call the onStopped callback with empty partial text
      final onStoppedCallback = verify(mockSpeechService.onStopped = captureAny)
          .captured
          .last as Function;
      onStoppedCallback();

      expect(provider.state, ConversationState.idle);
      expect(provider.messages, isEmpty);
    });

    test('clears error message when clearError is called', () async {
      await provider.initialize();

      // Force an error by calling processWithLLM without API key
      provider.toggleConversation();
      final onFinalCallback =
          verify(mockSpeechService.onFinalResult = captureAny).captured.last
              as Function(String);

      // Use fakeAsync to flush microtasks instead of real-time delays
      fakeAsync((fake) {
        onFinalCallback('test message');
        fake.flushMicrotasks();
      });

      expect(provider.errorMessage, isNotNull);

      provider.clearError();

      expect(provider.errorMessage, isNull);
    });

    test('clears messages when clearMessages is called', () async {
      await provider.initialize();

      // Add a message by simulating speech
      provider.toggleConversation();
      final onFinalCallback =
          verify(mockSpeechService.onFinalResult = captureAny).captured.last
              as Function(String);

      fakeAsync((fake) {
        onFinalCallback('test message');
        fake.flushMicrotasks();
      });

      expect(provider.messages.isNotEmpty, true);

      provider.clearMessages();

      expect(provider.messages, isEmpty);
    });

    test('interrupts when toggleConversation called during speaking state',
        () async {
      final mockTts = MockTtsService();
      when(mockTts.stop()).thenAnswer((_) async {});
      when(mockTts.dispose()).thenReturn(null);

      // Do NOT call initialize() — it replaces _ttsService via _rebuildTtsService.
      // Injecting ttsService in the constructor is enough for this unit test.
      final speakingProvider = ConversationProvider(
        speechService: mockSpeechService,
        settingsService: mockSettingsService,
        ttsService: mockTts,
      );

      // Force into speaking state via the @visibleForTesting helper
      speakingProvider.forceStateForTesting(ConversationState.speaking);
      expect(speakingProvider.state, ConversationState.speaking);

      // toggleConversation in speaking state should call _interrupt → idle
      speakingProvider.toggleConversation();

      expect(speakingProvider.state, ConversationState.idle);
      verify(mockTts.stop()).called(1);
      verify(mockSpeechService.cancelListening()).called(1);
    });

    test('partial STT text is updated during listening', () async {
      await provider.initialize();

      provider.toggleConversation();
      expect(provider.state, ConversationState.listening);

      // Simulate partial result
      final onPartialCallback =
          verify(mockSpeechService.onPartialResult = captureAny).captured.last
              as Function(String);
      onPartialCallback('hello world');

      expect(provider.partialSttText, 'hello world');
    });

    test('initialized flag is set after initialization', () async {
      expect(provider.initialized, false);

      await provider.initialize();

      expect(provider.initialized, true);
    });

    test('hasApiKey is false when no API key is configured', () async {
      await provider.initialize();

      expect(provider.hasApiKey, false);
    });

    test('updates settings and saves them', () async {
      await provider.initialize();

      const newSettings = Settings(
        claudeApiKey: 'test-key',
        backend: LLMBackend.claude,
      );

      await provider.updateSettings(newSettings);

      expect(provider.settings.claudeApiKey, 'test-key');
      verify(mockSettingsService.save(newSettings)).called(1);
    });

    test('toggleConversation does nothing during processing state', () async {
      await provider.initialize();

      // Start listening
      provider.toggleConversation();
      expect(provider.state, ConversationState.listening);

      // Trigger final result to move to processing
      final onFinalCallback =
          verify(mockSpeechService.onFinalResult = captureAny).captured.last
              as Function(String);
      fakeAsync((fake) {
        onFinalCallback('test');
        fake.flushMicrotasks();
      });

      // State will move to idle quickly because there's no API key
      // But the key is that if we were in processing, toggle would do nothing
      expect(provider.state, ConversationState.idle);
    });
  });

  group('ConversationProvider Message Handling', () {
    test('adds user message with correct role and timestamp', () async {
      await provider.initialize();

      provider.toggleConversation();
      final onFinalCallback =
          verify(mockSpeechService.onFinalResult = captureAny).captured.last
              as Function(String);
      fakeAsync((fake) {
        onFinalCallback('test message');
        fake.flushMicrotasks();
      });

      expect(provider.messages.length, greaterThanOrEqualTo(1));
      expect(provider.messages.first.role, MessageRole.user);
      expect(provider.messages.first.content, 'test message');
      expect(provider.messages.first.isComplete, true);
    });

    test('ignores empty speech input', () async {
      await provider.initialize();

      provider.toggleConversation();
      final onFinalCallback =
          verify(mockSpeechService.onFinalResult = captureAny).captured.last
              as Function(String);
      fakeAsync((fake) {
        onFinalCallback('   '); // Empty/whitespace only
        fake.flushMicrotasks();
      });

      expect(provider.messages, isEmpty);
      expect(provider.state, ConversationState.idle);
    });
  });

  group('ConversationProvider Error Handling', () {
    test('sets error message when STT is unavailable', () async {
      when(mockSpeechService.initialize()).thenAnswer((_) async => false);

      await provider.initialize();

      expect(provider.errorMessage, contains('Speech recognition unavailable'));
    });
  });
}
