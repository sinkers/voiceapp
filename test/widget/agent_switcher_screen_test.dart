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

  final instance1 = OpenClawAgentConfig(
    instance: const OpenClawInstance(
      id: 'inst-1',
      name: 'Pi Home',
      baseUrl: 'http://10.0.0.1/v1',
      sessionId: 'ses-1',
    ),
    agentId: 'main',
  );

  final instance2 = OpenClawAgentConfig(
    instance: const OpenClawInstance(
      id: 'inst-2',
      name: 'Pi Work',
      baseUrl: 'http://10.0.0.2/v1',
      sessionId: 'ses-2',
    ),
    agentId: 'assistant',
  );

  setUp(() {
    mockSwitcher = MockAgentSwitcherProvider();
    mockProvider = MockConversationProvider();

    // AgentSwitcherProvider defaults
    when(mockSwitcher.agents).thenReturn([instance1, instance2]);
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
  Future<void> pumpFor(WidgetTester tester, [Duration d = const Duration(milliseconds: 500)]) async {
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

      // instance1.displayName == 'main' (the agentId)
      expect(find.text('main'), findsOneWidget);
    });

    testWidgets('shows provider label for first agent', (tester) async {
      await tester.pumpWidget(createHomeScreen());
      await tester.pump();

      expect(find.text('OpenClaw · Pi Home'), findsOneWidget);
    });

    testWidgets('shows page indicator dots', (tester) async {
      await tester.pumpWidget(createHomeScreen());
      await tester.pump();

      // Two agents → two dot containers
      expect(find.byType(AnimatedContainer), findsAtLeastNWidgets(2));
    });

    testWidgets('swiping left calls setCurrentIndex with next page',
        (tester) async {
      await tester.pumpWidget(createHomeScreen());
      await tester.pump();

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await pumpFor(tester);

      verify(mockSwitcher.setCurrentIndex(1)).called(1);
    });

    testWidgets('second agent name visible when starting at page 1',
        (tester) async {
      when(mockSwitcher.currentIndex).thenReturn(1);
      when(mockSwitcher.agents).thenReturn([instance1, instance2]);

      await tester.pumpWidget(createHomeScreen());
      // HomeScreen reads currentIndex=1 for PageController initialPage
      await tester.pump();

      // The PageController initialPage=1, so instance2 page is first visible.
      // instance2.displayName == 'assistant'
      expect(find.text('assistant'), findsOneWidget);
    });
  });
}
