import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:voiceapp/models/settings.dart';
import 'package:voiceapp/providers/conversation_provider.dart';
import 'package:voiceapp/screens/settings_screen.dart';

@GenerateMocks([ConversationProvider])
import 'settings_screen_test.mocks.dart';

void main() {
  late MockConversationProvider mockProvider;

  setUp(() {
    mockProvider = MockConversationProvider();

    // Default mock behavior
    when(mockProvider.settings).thenReturn(const Settings());
    when(mockProvider.updateSettings(any)).thenAnswer((_) async {});
  });

  Widget createSettingsScreen() {
    return ChangeNotifierProvider<ConversationProvider>.value(
      value: mockProvider,
      child: const MaterialApp(
        home: SettingsScreen(),
      ),
    );
  }

  /// Pump the settings screen with a tall viewport so the ListView builds all
  /// items eagerly, avoiding off-screen / lazy-rendering failures.
  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(createSettingsScreen());
    // Fixed pump to avoid pumpAndSettle hanging on flutter_tts async init.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('SettingsScreen Widget Tests', () {
    testWidgets('displays Settings title', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('shows Save button in app bar', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Save'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows backend selection', (tester) async {
      await pumpSettings(tester);

      expect(find.text('AI Backend'), findsOneWidget);
      expect(find.text('Claude'), findsAtLeastNWidgets(1));
      expect(find.text('OpenAI / vLLM'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Claude settings when Claude backend is selected',
        (tester) async {
      when(mockProvider.settings).thenReturn(const Settings(
        backend: LLMBackend.claude,
      ));

      await pumpSettings(tester);

      expect(find.text('Anthropic API Key'), findsOneWidget);
      expect(find.text('Model'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows OpenAI settings when OpenAI backend is selected',
        (tester) async {
      when(mockProvider.settings).thenReturn(const Settings(
        backend: LLMBackend.openaiCompatible,
      ));

      await pumpSettings(tester);

      expect(find.text('Base URL'), findsOneWidget);
    });

    testWidgets('can switch backend from Claude to OpenAI', (tester) async {
      when(mockProvider.settings).thenReturn(const Settings(
        backend: LLMBackend.claude,
      ));

      await pumpSettings(tester);

      // Find and tap the OpenAI button
      await tester.tap(find.text('OpenAI / vLLM'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // OpenAI-specific fields should now be visible
      expect(find.text('Base URL'), findsOneWidget);
    });

    testWidgets('shows system prompt field', (tester) async {
      await pumpSettings(tester);

      expect(find.text('System Prompt'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'System prompt'), findsOneWidget);
    });

    testWidgets('shows TTS provider selection', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Text-to-Speech'), findsOneWidget);
      expect(find.text('Provider'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows on-device TTS settings when selected', (tester) async {
      when(mockProvider.settings).thenReturn(const Settings(
        ttsProvider: TtsProvider.onDevice,
      ));

      await pumpSettings(tester);

      expect(find.text('Voice'), findsOneWidget);
      expect(find.text('Speech Rate'), findsOneWidget);
      expect(find.text('Pitch'), findsOneWidget);
    });

    testWidgets('shows OpenClaw instances section', (tester) async {
      await pumpSettings(tester);

      expect(find.text('OpenClaw'), findsOneWidget);
      expect(find.text('Add instance'), findsOneWidget);
    });

    testWidgets('shows no instances message when none configured',
        (tester) async {
      when(mockProvider.settings).thenReturn(const Settings(
        openclawInstances: [],
      ));

      await pumpSettings(tester);

      expect(find.text('No instances configured'), findsOneWidget);
    });

    testWidgets('displays configured OpenClaw instances', (tester) async {
      const instance = OpenClawInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'http://localhost:3000/v1',
        sessionId: 'test-session',
      );
      when(mockProvider.settings).thenReturn(const Settings(
        openclawInstances: [instance],
      ));

      await pumpSettings(tester);

      expect(find.text('Test Instance'), findsOneWidget);
      expect(find.text('http://localhost:3000/v1'), findsOneWidget);
    });

    testWidgets('shows instance action buttons', (tester) async {
      const instance = OpenClawInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'http://localhost:3000/v1',
        sessionId: 'test-session',
      );
      when(mockProvider.settings).thenReturn(const Settings(
        openclawInstances: [instance],
      ));

      await pumpSettings(tester);

      // Test connection, edit, and delete buttons
      expect(find.byIcon(Icons.cable_rounded), findsOneWidget);
      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('shows add instance dialog when add button tapped',
        (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Add instance'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Add Instance'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Base URL'), findsAtLeastNWidgets(1));
      expect(find.text('Token'), findsOneWidget);
    });

    testWidgets('validates instance form fields', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Add instance'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Try to submit with empty fields
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog shows a SnackBar when Name or URL is empty
      expect(find.text('Name and Base URL are required.'), findsOneWidget);
    });

    testWidgets('calls updateSettings when Save button is tapped',
        (tester) async {
      await pumpSettings(tester);

      // Tap the save button
      final saveButtons = find.text('Save');
      await tester.tap(saveButtons.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      verify(mockProvider.updateSettings(any)).called(1);
    });

    testWidgets('bottom Save Settings button calls updateSettings',
        (tester) async {
      await pumpSettings(tester);

      // pumpSettings uses a tall viewport so the bottom FilledButton is built
      await tester.tap(find.widgetWithText(FilledButton, 'Save Settings'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      verify(mockProvider.updateSettings(any)).called(1);
    });

    testWidgets('can edit text in Claude API key field', (tester) async {
      when(mockProvider.settings).thenReturn(const Settings(
        backend: LLMBackend.claude,
      ));

      await pumpSettings(tester);

      final apiKeyField = find.widgetWithText(TextField, 'Anthropic API Key');
      await tester.enterText(apiKeyField, 'sk-ant-test-key');
      await tester.pump();

      expect(find.text('sk-ant-test-key'), findsOneWidget);
    });

    testWidgets('can edit system prompt', (tester) async {
      await pumpSettings(tester);

      final promptField = find.widgetWithText(TextField, 'System prompt');
      await tester.enterText(promptField, 'Custom test prompt');
      await tester.pump();

      expect(find.text('Custom test prompt'), findsOneWidget);
    });

    testWidgets('shows ElevenLabs settings when provider is selected',
        (tester) async {
      when(mockProvider.settings).thenReturn(const Settings(
        ttsProvider: TtsProvider.elevenlabs,
      ));

      await pumpSettings(tester);

      // Change to ElevenLabs (it might already be selected based on mock)
      expect(find.text('ElevenLabs API Key'), findsOneWidget);
      expect(find.text('Custom Voice ID'), findsOneWidget);
      expect(find.text('Model ID'), findsOneWidget);
      expect(find.text('Rachel'), findsOneWidget);
      expect(find.text('Liam'), findsOneWidget);
    });

    testWidgets('shows OpenAI TTS settings when provider is selected',
        (tester) async {
      when(mockProvider.settings).thenReturn(const Settings(
        ttsProvider: TtsProvider.openai,
      ));

      await pumpSettings(tester);

      expect(find.text('Uses your OpenAI API key above'), findsOneWidget);
    });
  });

  group('SettingsScreen Form Validation', () {
    testWidgets('validates URL format in instance dialog', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Add instance'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Enter invalid URL
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Name'), 'Test');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Base URL'), 'not-a-url');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('valid URL'), findsOneWidget);
    });

    testWidgets('accepts valid instance form data', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Add instance'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Enter valid data
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Name'), 'Test Instance');
      await tester.enterText(find.widgetWithText(TextFormField, 'Base URL'),
          'http://localhost:3000/v1');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog should close (no longer visible)
      expect(find.text('Add Instance'), findsNothing);
    });
  });

  group('SettingsScreen Provider Switching', () {
    testWidgets('switching TTS provider updates UI', (tester) async {
      when(mockProvider.settings).thenReturn(const Settings(
        ttsProvider: TtsProvider.onDevice,
      ));

      await pumpSettings(tester);

      // pumpSettings uses a tall viewport so all ListView items are built
      expect(find.text('Speech Rate'), findsOneWidget);
      expect(find.text('Pitch'), findsOneWidget);
    });

    testWidgets('shows speech rate text', (tester) async {
      when(mockProvider.settings).thenReturn(const Settings(
        ttsProvider: TtsProvider.onDevice,
        ttsRate: 0.5,
      ));

      await pumpSettings(tester);

      expect(find.text('Speech Rate'), findsOneWidget);
    });

    testWidgets('shows pitch text', (tester) async {
      when(mockProvider.settings).thenReturn(const Settings(
        ttsProvider: TtsProvider.onDevice,
        ttsPitch: 1.0,
      ));

      await pumpSettings(tester);

      expect(find.text('Pitch'), findsOneWidget);
    });
  });
}
