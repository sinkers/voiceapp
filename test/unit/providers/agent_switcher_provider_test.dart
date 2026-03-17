import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voiceapp/models/agent_config.dart';
import 'package:voiceapp/models/conversation_state.dart';
import 'package:voiceapp/models/settings.dart';
import 'package:voiceapp/models/voice_config.dart';
import 'package:voiceapp/providers/agent_switcher_provider.dart';
import 'package:voiceapp/providers/conversation_provider.dart';
import 'package:voiceapp/services/settings_service.dart';
import 'package:voiceapp/services/speech_service.dart';

@GenerateMocks([ConversationProvider, SpeechService])
import 'agent_switcher_provider_test.mocks.dart';

// Minimal fake SettingsService that returns a preset Settings object.
class _FakeSettingsService extends SettingsService {
  final Settings preset;
  _FakeSettingsService(this.preset);

  @override
  Future<Settings> load() async => preset;

  @override
  Future<void> save(Settings settings) async {}
}

// Helper to create test agent configs
AgentConfig _makeClaudeAgent(String id, String name, String voiceId) =>
    AgentConfig(
      id: id,
      name: name,
      type: AgentType.claude,
      apiKey: 'test-key',
      model: 'claude-opus-4-6',
      voiceId: voiceId,
    );

AgentConfig _makeOpenClawAgent(
  String id,
  String name,
  String serverId,
  String agentName,
  String voiceId,
) =>
    AgentConfig(
      id: id,
      name: name,
      type: AgentType.openclaw,
      serverId: serverId,
      agentName: agentName,
      voiceId: voiceId,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final voiceSystem = VoiceConfig.system();
  final agent1 = _makeClaudeAgent('agent-1', 'Claude 1', voiceSystem.id);
  final agent2 = _makeClaudeAgent('agent-2', 'Claude 2', voiceSystem.id);
  final agent3 = _makeOpenClawAgent(
    'agent-3',
    'OpenClaw 1',
    'server-1',
    'main',
    voiceSystem.id,
  );
  final agent4 = _makeOpenClawAgent(
    'agent-4',
    'OpenClaw 2',
    'server-2',
    'main',
    voiceSystem.id,
  );

  final twoAgents = Settings(
    agents: [agent1, agent2],
    voices: [voiceSystem],
  );

  final fourAgents = Settings(
    agents: [agent1, agent2, agent3, agent4],
    voices: [voiceSystem],
  );

  MockConversationProvider makeMockProvider() {
    final mock = MockConversationProvider();
    when(mock.initializeForAgent(any)).thenAnswer((_) async {});
    when(mock.updateSettings(any)).thenAnswer((_) async {});
    when(mock.state).thenReturn(ConversationState.idle);
    when(mock.messages).thenReturn([]);
    when(mock.partialSttText).thenReturn('');
    when(mock.settings).thenReturn(const Settings());
    when(mock.errorMessage).thenReturn(null);
    when(mock.initialized).thenReturn(true);
    when(mock.hasApiKey).thenReturn(false);
    when(mock.hasListeners).thenReturn(false);
    return mock;
  }

  group('AgentSwitcherProvider', () {
    test('initializes with currentIndex 0', () async {
      final switcher = AgentSwitcherProvider(
        settingsService: _FakeSettingsService(twoAgents),
        speechService: MockSpeechService(),
        providerFactory: makeMockProvider,
      );
      await switcher.initialize();

      expect(switcher.currentIndex, 0);
    });

    test('agents list is built from settings', () async {
      final switcher = AgentSwitcherProvider(
        settingsService: _FakeSettingsService(fourAgents),
        speechService: MockSpeechService(),
        providerFactory: makeMockProvider,
      );
      await switcher.initialize();

      expect(switcher.agents.length, 4);
      expect(switcher.agents[0].type, AgentType.claude);
      expect(switcher.agents[1].type, AgentType.claude);
      expect(switcher.agents[2].type, AgentType.openclaw);
      expect(switcher.agents[3].type, AgentType.openclaw);
    });

    test(
      'setCurrentIndex changes currentIndex and persists to prefs',
      () async {
        final switcher = AgentSwitcherProvider(
          settingsService: _FakeSettingsService(fourAgents),
          speechService: MockSpeechService(),
          providerFactory: makeMockProvider,
        );
        await switcher.initialize();

        await switcher.setCurrentIndex(2);

        expect(switcher.currentIndex, 2);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('last_active_agent_id'), switcher.agents[2].id);
      },
    );

    test('setCurrentIndex ignores out-of-range values', () async {
      final switcher = AgentSwitcherProvider(
        settingsService: _FakeSettingsService(twoAgents),
        speechService: MockSpeechService(),
        providerFactory: makeMockProvider,
      );
      await switcher.initialize();

      await switcher.setCurrentIndex(99);
      expect(switcher.currentIndex, 0); // unchanged
    });

    test('switching agent index changes active ConversationProvider', () async {
      final switcher = AgentSwitcherProvider(
        settingsService: _FakeSettingsService(fourAgents),
        speechService: MockSpeechService(),
        providerFactory: makeMockProvider,
      );
      await switcher.initialize();

      final p0 = switcher.providerFor(switcher.agents[0]);
      final p1 = switcher.providerFor(switcher.agents[1]);

      // Index 0 → provider for agent 0
      expect(identical(p0, switcher.providerFor(switcher.agents[0])), isTrue);
      // Switching index → different provider
      expect(identical(p0, p1), isFalse);
      expect(identical(p1, switcher.providerFor(switcher.agents[1])), isTrue);
    });

    test('providerFor returns a ConversationProvider for an agent', () async {
      final switcher = AgentSwitcherProvider(
        settingsService: _FakeSettingsService(twoAgents),
        speechService: MockSpeechService(),
        providerFactory: makeMockProvider,
      );
      await switcher.initialize();

      final agent = switcher.agents.first;
      final provider = switcher.providerFor(agent);

      expect(provider, isA<ConversationProvider>());
    });

    test('providerFor returns the same instance on repeated calls', () async {
      final switcher = AgentSwitcherProvider(
        settingsService: _FakeSettingsService(twoAgents),
        speechService: MockSpeechService(),
        providerFactory: makeMockProvider,
      );
      await switcher.initialize();

      final agent = switcher.agents.first;
      final p1 = switcher.providerFor(agent);
      final p2 = switcher.providerFor(agent);

      expect(identical(p1, p2), isTrue);
    });

    test('different agents get different ConversationProviders', () async {
      final switcher = AgentSwitcherProvider(
        settingsService: _FakeSettingsService(fourAgents),
        speechService: MockSpeechService(),
        providerFactory: makeMockProvider,
      );
      await switcher.initialize();

      final p0 = switcher.providerFor(switcher.agents[0]);
      final p1 = switcher.providerFor(switcher.agents[1]);

      expect(identical(p0, p1), isFalse);
    });

    test('restores last active agent index from SharedPreferences', () async {
      final targetId = agent3.id; // third agent

      SharedPreferences.setMockInitialValues({
        'last_active_agent_id': targetId,
      });

      final switcher = AgentSwitcherProvider(
        settingsService: _FakeSettingsService(fourAgents),
        speechService: MockSpeechService(),
        providerFactory: makeMockProvider,
      );
      await switcher.initialize();

      expect(switcher.currentIndex, 2);
    });

    test('providerFor initializes with correct selectedAgentId', () async {
      Settings? capturedSettings0;
      Settings? capturedSettings1;

      final switcher = AgentSwitcherProvider(
        settingsService: _FakeSettingsService(twoAgents),
        speechService: MockSpeechService(),
        providerFactory: () {
          final mock = MockConversationProvider();
          when(mock.initializeForAgent(argThat(isA<Settings>()))).thenAnswer((
            invocation,
          ) {
            final settings = invocation.positionalArguments[0] as Settings;
            if (capturedSettings0 == null) {
              capturedSettings0 = settings;
            } else {
              capturedSettings1 = settings;
            }
            return Future.value();
          });
          when(
            mock.updateSettings(argThat(isA<Settings>())),
          ).thenAnswer((_) async {});
          when(mock.state).thenReturn(ConversationState.idle);
          when(mock.messages).thenReturn([]);
          when(mock.partialSttText).thenReturn('');
          when(mock.settings).thenReturn(const Settings());
          when(mock.errorMessage).thenReturn(null);
          when(mock.initialized).thenReturn(true);
          when(mock.hasApiKey).thenReturn(false);
          when(mock.hasListeners).thenReturn(false);
          return mock;
        },
      );
      await switcher.initialize();

      switcher.providerFor(agent1);
      switcher.providerFor(agent2);

      // Verify correct selectedAgentId was set for each provider
      expect(capturedSettings0?.selectedAgentId, agent1.id);
      expect(capturedSettings1?.selectedAgentId, agent2.id);
    });
  });
}
