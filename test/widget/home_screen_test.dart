import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:voiceapp/models/agent_config.dart';
import 'package:voiceapp/models/conversation_state.dart';
import 'package:voiceapp/models/message.dart';
import 'package:voiceapp/models/settings.dart';
import 'package:voiceapp/providers/conversation_provider.dart';
import 'package:voiceapp/screens/home_screen.dart';
import 'package:voiceapp/widgets/mic_button.dart';

@GenerateMocks([ConversationProvider])
import 'home_screen_test.mocks.dart';

void main() {
  late MockConversationProvider mockProvider;

  const dummyAgent = DirectModelAgentConfig(
    backend: LLMBackend.claude,
    modelName: 'claude-opus-4-6',
  );

  setUp(() {
    mockProvider = MockConversationProvider();

    // Default mock behavior
    when(mockProvider.state).thenReturn(ConversationState.idle);
    when(mockProvider.messages).thenReturn([]);
    when(mockProvider.partialSttText).thenReturn('');
    when(mockProvider.settings).thenReturn(const Settings());
    when(mockProvider.errorMessage).thenReturn(null);
    when(mockProvider.initialized).thenReturn(true);
    when(mockProvider.hasApiKey).thenReturn(true);
  });

  Widget createAgentPage() {
    return ChangeNotifierProvider<ConversationProvider>.value(
      value: mockProvider,
      child: const MaterialApp(home: AgentConversationPage(agent: dummyAgent)),
    );
  }

  group('AgentConversationPage Widget Tests', () {
    testWidgets('displays agent displayName in app bar', (tester) async {
      await tester.pumpWidget(createAgentPage());

      expect(find.text('claude-opus-4-6'), findsOneWidget);
    });

    testWidgets('displays providerLabel badge', (tester) async {
      await tester.pumpWidget(createAgentPage());

      expect(find.text('Anthropic'), findsOneWidget);
    });

    testWidgets('shows mic button in all states', (tester) async {
      await tester.pumpWidget(createAgentPage());

      expect(find.byType(MicButton), findsOneWidget);
    });

    testWidgets('shows empty state when no messages', (tester) async {
      await tester.pumpWidget(createAgentPage());

      expect(find.text('Tap the mic to start talking'), findsOneWidget);
    });

    testWidgets('shows messages when conversation has content', (tester) async {
      final now = DateTime(2024);
      when(mockProvider.messages).thenReturn([
        Message(
          id: '1',
          role: MessageRole.user,
          content: 'Hello',
          timestamp: now,
        ),
      ]);

      await tester.pumpWidget(createAgentPage());

      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Tap the mic to start talking'), findsNothing);
    });

    testWidgets('shows setup prompt when no API key', (tester) async {
      when(mockProvider.hasApiKey).thenReturn(false);

      await tester.pumpWidget(createAgentPage());

      expect(find.text('Add your API key to get started.'), findsOneWidget);
      expect(find.text('Setup'), findsOneWidget);
    });

    testWidgets('shows partial STT text during listening', (tester) async {
      when(mockProvider.state).thenReturn(ConversationState.listening);
      when(mockProvider.partialSttText).thenReturn('Testing speech...');

      await tester.pumpWidget(createAgentPage());

      expect(find.text('Testing speech...'), findsOneWidget);
    });

    testWidgets('hides partial STT text when not listening', (tester) async {
      when(mockProvider.state).thenReturn(ConversationState.idle);
      when(mockProvider.partialSttText).thenReturn('');

      await tester.pumpWidget(createAgentPage());

      expect(find.text('Testing speech...'), findsNothing);
    });

    testWidgets('shows clear button when messages exist', (tester) async {
      final now = DateTime(2024);
      when(mockProvider.messages).thenReturn([
        Message(
          id: '1',
          role: MessageRole.user,
          content: 'Test',
          timestamp: now,
        ),
      ]);

      await tester.pumpWidget(createAgentPage());

      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('hides clear button when no messages', (tester) async {
      when(mockProvider.messages).thenReturn([]);

      await tester.pumpWidget(createAgentPage());

      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });

    testWidgets('shows settings button', (tester) async {
      await tester.pumpWidget(createAgentPage());

      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    });
  });

  group('AgentConversationPage Error Banner Tests', () {
    testWidgets('shows error banner when error message is set', (tester) async {
      when(mockProvider.errorMessage).thenReturn('Test error message');

      await tester.pumpWidget(createAgentPage());

      expect(find.text('Test error message'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('hides error banner when no error', (tester) async {
      when(mockProvider.errorMessage).thenReturn(null);

      await tester.pumpWidget(createAgentPage());

      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('error banner has dismiss button', (tester) async {
      when(mockProvider.errorMessage).thenReturn('Test error');

      await tester.pumpWidget(createAgentPage());

      expect(find.widgetWithIcon(IconButton, Icons.close), findsOneWidget);
    });

    testWidgets('dismiss button calls clearError', (tester) async {
      when(mockProvider.errorMessage).thenReturn('Test error');

      await tester.pumpWidget(createAgentPage());

      final closeButton = find.widgetWithIcon(IconButton, Icons.close);
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      await tester.pump();

      verify(mockProvider.clearError()).called(1);
    });
  });

  group('AgentConversationPage Mic Button States', () {
    testWidgets('mic button shows idle state', (tester) async {
      when(mockProvider.state).thenReturn(ConversationState.idle);

      await tester.pumpWidget(createAgentPage());

      final micButton = tester.widget<MicButton>(find.byType(MicButton));
      expect(micButton.state, ConversationState.idle);
    });

    testWidgets('mic button shows listening state', (tester) async {
      when(mockProvider.state).thenReturn(ConversationState.listening);

      await tester.pumpWidget(createAgentPage());

      final micButton = tester.widget<MicButton>(find.byType(MicButton));
      expect(micButton.state, ConversationState.listening);
    });

    testWidgets('mic button shows processing state', (tester) async {
      when(mockProvider.state).thenReturn(ConversationState.processing);

      await tester.pumpWidget(createAgentPage());

      final micButton = tester.widget<MicButton>(find.byType(MicButton));
      expect(micButton.state, ConversationState.processing);
    });

    testWidgets('mic button shows speaking state', (tester) async {
      when(mockProvider.state).thenReturn(ConversationState.speaking);

      await tester.pumpWidget(createAgentPage());

      final micButton = tester.widget<MicButton>(find.byType(MicButton));
      expect(micButton.state, ConversationState.speaking);
    });

    testWidgets('tapping mic button calls toggleConversation', (tester) async {
      await tester.pumpWidget(createAgentPage());

      await tester.tap(find.byType(MicButton));
      await tester.pump();

      verify(mockProvider.toggleConversation()).called(1);
    });
  });

  group('AgentConversationPage Clear Conversation', () {
    // MicButton uses a repeating AnimationController, so pumpAndSettle never
    // settles. Use pump(Duration) to advance past dialog open/close animations.
    Future<void> pumpDialog(WidgetTester tester) async {
      await tester.pump(); // start dialog animation
      await tester.pump(const Duration(milliseconds: 300)); // finish open
    }

    testWidgets('shows confirmation dialog when clear button tapped', (
      tester,
    ) async {
      final now = DateTime(2024);
      when(mockProvider.messages).thenReturn([
        Message(
          id: '1',
          role: MessageRole.user,
          content: 'Test',
          timestamp: now,
        ),
      ]);

      await tester.pumpWidget(createAgentPage());

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await pumpDialog(tester);

      expect(find.text('Clear conversation?'), findsOneWidget);
      expect(
        find.text('This will delete all messages in the current conversation.'),
        findsOneWidget,
      );
    });

    testWidgets('calls clearMessages when confirmed', (tester) async {
      final now = DateTime(2024);
      when(mockProvider.messages).thenReturn([
        Message(
          id: '1',
          role: MessageRole.user,
          content: 'Test',
          timestamp: now,
        ),
      ]);

      await tester.pumpWidget(createAgentPage());

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await pumpDialog(tester);

      await tester.tap(find.text('Clear'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(mockProvider.clearMessages()).called(1);
    });

    testWidgets('does not clear messages when cancelled', (tester) async {
      final now = DateTime(2024);
      when(mockProvider.messages).thenReturn([
        Message(
          id: '1',
          role: MessageRole.user,
          content: 'Test',
          timestamp: now,
        ),
      ]);

      await tester.pumpWidget(createAgentPage());

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await pumpDialog(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verifyNever(mockProvider.clearMessages());
    });
  });
}
