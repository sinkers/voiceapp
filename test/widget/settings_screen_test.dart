import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:voiceapp/models/agent_config.dart';
import 'package:voiceapp/models/settings.dart';
import 'package:voiceapp/models/voice_config.dart';
import 'package:voiceapp/providers/agent_switcher_provider.dart';
import 'package:voiceapp/screens/settings_screen.dart';

@GenerateMocks([AgentSwitcherProvider])
import 'settings_screen_test.mocks.dart';

void main() {
  late MockAgentSwitcherProvider mockProvider;

  setUp(() {
    mockProvider = MockAgentSwitcherProvider();

    // Default mock behavior
    when(mockProvider.settings).thenReturn(const Settings());
    when(mockProvider.updateSettings(any)).thenAnswer((_) async {});
  });

  Widget createSettingsScreen() {
    return ChangeNotifierProvider<AgentSwitcherProvider>.value(
      value: mockProvider,
      child: const MaterialApp(home: SettingsScreen()),
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

    testWidgets('shows system prompt field', (tester) async {
      await pumpSettings(tester);

      expect(find.text('System Prompt'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'System prompt'), findsOneWidget);
    });

    testWidgets('shows Agents section', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Agents'), findsOneWidget);
      expect(find.text('Add Agent'), findsOneWidget);
    });

    testWidgets('shows Voice Providers section', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Voice Providers'), findsOneWidget);
      expect(find.text('Add Voice Provider'), findsOneWidget);
    });

    testWidgets('shows OpenClaw Servers section when servers exist',
        (tester) async {
      const server = OpenClawServer(
        id: 'test-id',
        name: 'Test Server',
        baseUrl: 'http://localhost:3000/v1',
      );
      when(
        mockProvider.settings,
      ).thenReturn(const Settings(openclawServers: [server]));

      await pumpSettings(tester);

      expect(find.text('OpenClaw Servers'), findsOneWidget);
    });

    testWidgets('shows Conversational Mode section', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Conversational Mode'), findsOneWidget);
    });

    testWidgets('shows no agents message when none configured', (
      tester,
    ) async {
      when(
        mockProvider.settings,
      ).thenReturn(const Settings(agents: []));

      await pumpSettings(tester);

      expect(find.text('No agents configured'), findsOneWidget);
    });

    testWidgets('displays configured agents', (tester) async {
      final voice = VoiceConfig.system();
      final agent = AgentConfig.claude(
        name: 'Test Claude',
        apiKey: 'test-key',
        voiceId: voice.id,
        model: 'claude-opus-4-6',
      );
      when(
        mockProvider.settings,
      ).thenReturn(Settings(agents: [agent], voices: [voice]));

      await pumpSettings(tester);

      expect(find.text('Test Claude'), findsOneWidget);
      // Subtitle shows model and voice
      expect(find.textContaining('claude-opus-4-6'), findsOneWidget);
    });

    testWidgets('shows no voices message when none configured', (
      tester,
    ) async {
      when(
        mockProvider.settings,
      ).thenReturn(const Settings(voices: []));

      await pumpSettings(tester);

      // Voice section is always shown, just without any voice tiles
      expect(find.text('Voice Providers'), findsOneWidget);
    });

    testWidgets('displays configured voices', (tester) async {
      final voice = VoiceConfig.system(rate: 0.5, pitch: 1.0);
      when(
        mockProvider.settings,
      ).thenReturn(Settings(voices: [voice]));

      await pumpSettings(tester);

      expect(find.text('System'), findsOneWidget);
      expect(find.text('On-device TTS'), findsOneWidget);
    });

    testWidgets('shows no servers message when none configured', (
      tester,
    ) async {
      when(
        mockProvider.settings,
      ).thenReturn(const Settings(openclawServers: []));

      await pumpSettings(tester);

      // Server section is not shown when no servers exist
      expect(find.text('OpenClaw Servers'), findsNothing);
    });

    testWidgets('displays configured OpenClaw servers', (tester) async {
      const server = OpenClawServer(
        id: 'test-id',
        name: 'Test Server',
        baseUrl: 'http://localhost:3000/v1',
      );
      when(
        mockProvider.settings,
      ).thenReturn(const Settings(openclawServers: [server]));

      await pumpSettings(tester);

      expect(find.text('Test Server'), findsOneWidget);
      expect(find.text('http://localhost:3000/v1'), findsOneWidget);
    });

    testWidgets('shows agent action buttons', (tester) async {
      final agent = AgentConfig.claude(
        name: 'Test Agent',
        apiKey: 'test-key',
        voiceId: 'voice-1',
      );
      when(
        mockProvider.settings,
      ).thenReturn(Settings(agents: [agent]));

      await pumpSettings(tester);

      // Edit and delete buttons
      expect(find.byIcon(Icons.edit_rounded), findsAtLeastNWidgets(1));
      expect(
          find.byIcon(Icons.delete_outline_rounded), findsAtLeastNWidgets(1));
    });

    testWidgets('shows voice action buttons', (tester) async {
      // Use non-system voice so delete button is shown
      final voice = VoiceConfig.elevenlabs(
        name: 'Rachel',
        voiceId: 'rachel-id',
      );
      when(
        mockProvider.settings,
      ).thenReturn(Settings(voices: [voice]));

      await pumpSettings(tester);

      // Edit and delete buttons
      expect(find.byIcon(Icons.edit_rounded), findsAtLeastNWidgets(1));
      expect(
          find.byIcon(Icons.delete_outline_rounded), findsAtLeastNWidgets(1));
    });

    testWidgets('shows server action buttons', (tester) async {
      const server = OpenClawServer(
        id: 'test-id',
        name: 'Test Server',
        baseUrl: 'http://localhost:3000/v1',
      );
      when(
        mockProvider.settings,
      ).thenReturn(const Settings(openclawServers: [server]));

      await pumpSettings(tester);

      // Edit and delete buttons
      expect(find.byIcon(Icons.edit_rounded), findsAtLeastNWidgets(1));
      expect(
          find.byIcon(Icons.delete_outline_rounded), findsAtLeastNWidgets(1));
    });

    testWidgets('calls updateSettings when Save button is tapped', (
      tester,
    ) async {
      await pumpSettings(tester);

      // Tap the save button
      final saveButtons = find.text('Save');
      await tester.tap(saveButtons.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      verify(mockProvider.updateSettings(any)).called(1);
    });

    testWidgets('bottom Save Settings button calls updateSettings', (
      tester,
    ) async {
      await pumpSettings(tester);

      // pumpSettings uses a tall viewport so the bottom FilledButton is built
      await tester.tap(find.widgetWithText(FilledButton, 'Save Settings'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      verify(mockProvider.updateSettings(any)).called(1);
    });

    testWidgets('can edit system prompt', (tester) async {
      await pumpSettings(tester);

      final promptField = find.widgetWithText(TextField, 'System prompt');
      await tester.enterText(promptField, 'Custom test prompt');
      await tester.pump();

      expect(find.text('Custom test prompt'), findsOneWidget);
    });

    testWidgets('shows conversational mode switch', (tester) async {
      when(
        mockProvider.settings,
      ).thenReturn(const Settings(conversationalMode: false));

      await pumpSettings(tester);

      expect(find.text('Conversational Mode'), findsOneWidget);
      expect(find.byType(Switch), findsAtLeastNWidgets(1));
    });

    testWidgets('shows pause duration slider when conversational mode enabled',
        (
      tester,
    ) async {
      when(
        mockProvider.settings,
      ).thenReturn(
          const Settings(conversationalMode: true, pauseDuration: 1.5));

      await pumpSettings(tester);

      expect(find.text('Pause duration'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('hides pause duration slider when conversational mode disabled',
        (
      tester,
    ) async {
      when(
        mockProvider.settings,
      ).thenReturn(const Settings(conversationalMode: false));

      await pumpSettings(tester);

      expect(find.text('Pause Duration'), findsNothing);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('displays version info', (tester) async {
      await pumpSettings(tester);

      // Version info is displayed at the bottom
      expect(find.textContaining('ClawTalk'), findsOneWidget);
    });
  });

  group('SettingsScreen Agent Management', () {
    testWidgets('shows agent type picker when add agent tapped', (
      tester,
    ) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Add Agent'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Choose Agent Type'), findsOneWidget);
      expect(find.text('Claude'), findsAtLeastNWidgets(1));
      expect(find.text('OpenAI'), findsAtLeastNWidgets(1));
      expect(find.text('OpenClaw'), findsAtLeastNWidgets(1));
    });

    testWidgets('displays multiple agents', (tester) async {
      final agent1 = AgentConfig.claude(
        name: 'Claude Agent',
        apiKey: 'key1',
        voiceId: 'voice-1',
      );
      final agent2 = AgentConfig.openai(
        name: 'OpenAI Agent',
        apiKey: 'key2',
        voiceId: 'voice-1',
      );
      when(
        mockProvider.settings,
      ).thenReturn(Settings(agents: [agent1, agent2]));

      await pumpSettings(tester);

      expect(find.text('Claude Agent'), findsOneWidget);
      expect(find.text('OpenAI Agent'), findsOneWidget);
    });
  });

  group('SettingsScreen Voice Management', () {
    testWidgets('shows voice type picker when add voice tapped', (
      tester,
    ) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Add Voice Provider'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Choose Voice Provider'), findsOneWidget);
      expect(find.text('ElevenLabs'), findsAtLeastNWidgets(1));
      expect(find.text('OpenAI TTS'), findsAtLeastNWidgets(1));
    });

    testWidgets('displays multiple voices', (tester) async {
      final voice1 = VoiceConfig.system(rate: 0.5, pitch: 1.0);
      final voice2 = VoiceConfig.elevenlabs(
        name: 'Rachel',
        voiceId: 'rachel-id',
      );
      when(
        mockProvider.settings,
      ).thenReturn(Settings(voices: [voice1, voice2]));

      await pumpSettings(tester);

      expect(find.text('System'), findsOneWidget);
      expect(find.text('Rachel'), findsOneWidget);
    });
  });

  group('SettingsScreen Server Management', () {
    testWidgets('displays multiple servers', (tester) async {
      const server1 = OpenClawServer(
        id: 'server-1',
        name: 'Server 1',
        baseUrl: 'http://localhost:3000/v1',
      );
      const server2 = OpenClawServer(
        id: 'server-2',
        name: 'Server 2',
        baseUrl: 'http://10.0.0.1:8000/v1',
      );
      when(
        mockProvider.settings,
      ).thenReturn(const Settings(openclawServers: [server1, server2]));

      await pumpSettings(tester);

      expect(find.text('Server 1'), findsOneWidget);
      expect(find.text('Server 2'), findsOneWidget);
    });
  });
}
