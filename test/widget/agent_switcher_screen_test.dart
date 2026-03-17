import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:voiceapp/models/agent_config.dart';
import 'package:voiceapp/models/conversation_state.dart';
import 'package:voiceapp/models/settings.dart';
import 'package:voiceapp/providers/agent_switcher_provider.dart';
import 'package:voiceapp/providers/conversation_provider.dart';
import 'package:voiceapp/screens/home_screen.dart';

@GenerateMocks([AgentSwitcherProvider, ConversationProvider])
import 'agent_switcher_screen_test.mocks.dart';

void main() {
  late MockAgentSwitcherProvider mockSwitcher;
  late MockConversationProvider mockProvider;

  const agent1 = AgentConfig(
    id: 'agent-1',
    name: 'main',
    type: AgentType.openclaw,
    serverId: 'server-1',
    agentName: 'main',
    voiceId: 'voice-1',
  );

  const agent2 = AgentConfig(
    id: 'agent-2',
    name: 'assistant',
    type: AgentType.openclaw,
    serverId: 'server-2',
    agentName: 'assistant',
    voiceId: 'voice-1',
  );

  setUp(() {
    mockSwitcher = MockAgentSwitcherProvider();
    mockProvider = MockConversationProvider();

    // AgentSwitcherProvider defaults
    when(mockSwitcher.agents).thenReturn([agent1, agent2]);
    when(mockSwitcher.currentIndex).thenReturn(0);
    when(mockSwitcher.initialized).thenReturn(true);
    when(mockSwitcher.settings).thenReturn(const Settings());
    when(mockSwitcher.providerFor(any)).thenReturn(mockProvider);
    when(mockSwitcher.setCurrentIndex(any)).thenAnswer((_) async {});
    when(mockSwitcher.hasListeners).thenReturn(false);

    // ConversationProvider defaults
    when(mockProvider.state).thenReturn(ConversationState.idle);
    when(mockProvider.messages).thenReturn([]);
    when(mockProvider.partialSttText).thenReturn('');
    when(mockProvider.settings).thenReturn(const Settings());
    when(mockProvider.errorMessage).thenReturn(null);
    when(mockProvider.initialized).thenReturn(true);
    when(mockProvider.hasApiKey).thenReturn(true);
    when(mockProvider.hasListeners).thenReturn(false);
  });

  Widget createHomeScreen() {
    return ChangeNotifierProvider<AgentSwitcherProvider>.value(
      value: mockSwitcher,
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  // MicButton has a repeating animation so pumpAndSettle never settles.
  // Use pump(Duration) instead.
  Future<void> pumpFor(
    WidgetTester tester, [
    Duration d = const Duration(milliseconds: 500),
  ]) async {
    await tester.pump();
    await tester.pump(d);
  }

  group('HomeScreen PageView Tests', () {
    testWidgets('renders PageView with agents', (tester) async {
      await tester.pumpWidget(createHomeScreen());
      await tester.pump();

      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('shows first agent displayName on first page', (tester) async {
      await tester.pumpWidget(createHomeScreen());
      await tester.pump();

      // agent1.displayName == 'main' (the name)
      expect(find.text('main'), findsOneWidget);
    });

    testWidgets('shows provider label for first agent', (tester) async {
      await tester.pumpWidget(createHomeScreen());
      await tester.pump();

      expect(find.text('OpenClaw'), findsOneWidget);
    });

    testWidgets('shows page indicator dots', (tester) async {
      await tester.pumpWidget(createHomeScreen());
      await tester.pump();

      // Two agents → two dot containers
      expect(find.byType(AnimatedContainer), findsAtLeastNWidgets(2));
    });

    testWidgets('swiping left calls setCurrentIndex with next page', (
      tester,
    ) async {
      await tester.pumpWidget(createHomeScreen());
      await tester.pump();

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await pumpFor(tester);

      verify(mockSwitcher.setCurrentIndex(1)).called(1);
    });

    testWidgets('second agent name visible when starting at page 1', (
      tester,
    ) async {
      when(mockSwitcher.currentIndex).thenReturn(1);
      when(mockSwitcher.agents).thenReturn([agent1, agent2]);

      await tester.pumpWidget(createHomeScreen());
      // HomeScreen reads currentIndex=1 for PageController initialPage
      await tester.pump();

      // The PageController initialPage=1, so agent2 page is first visible.
      // agent2.displayName == 'assistant'
      expect(find.text('assistant'), findsOneWidget);
    });
  });
}
