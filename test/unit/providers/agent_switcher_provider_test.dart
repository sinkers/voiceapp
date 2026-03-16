import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voiceapp/models/agent_config.dart';
import 'package:voiceapp/models/conversation_state.dart';
import 'package:voiceapp/models/settings.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const twoInstances = Settings(
    openclawInstances: [
      OpenClawInstance(
        id: 'inst-1',
        name: 'Pi Home',
        baseUrl: 'http://10.0.0.1/v1',
        sessionId: 'ses-1',
      ),
      OpenClawInstance(
        id: 'inst-2',
        name: 'Pi Work',
        baseUrl: 'http://10.0.0.2/v1',
        sessionId: 'ses-2',
      ),
    ],
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
        settingsService: _FakeSettingsService(const Settings()),
        speechService: MockSpeechService(),
        providerFactory: makeMockProvider,
      );
      await switcher.initialize();

      expect(switcher.currentIndex, 0);
    });

    test('agents list is built from settings', () async {
      final switcher = AgentSwitcherProvider(
        settingsService: _FakeSettingsService(twoInstances),
        speechService: MockSpeechService(),
        providerFactory: makeMockProvider,
      );
      await switcher.initialize();

      // 2 OpenClaw + 2 direct
      expect(switcher.agents.length, 4);
      expect(switcher.agents[0], isA<OpenClawAgentConfig>());
      expect(switcher.agents[1], isA<OpenClawAgentConfig>());
      expect(switcher.agents[2], isA<DirectModelAgentConfig>());
      expect(switcher.agents[3], isA<DirectModelAgentConfig>());
    });

    test('setCurrentIndex changes currentIndex and persists to prefs',
        () async {
      final switcher = AgentSwitcherProvider(
        settingsService: _FakeSettingsService(twoInstances),
        speechService: MockSpeechService(),
        providerFactory: makeMockProvider,
      );
      await switcher.initialize();

      await switcher.setCurrentIndex(2);

      expect(switcher.currentIndex, 2);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('last_active_agent_id'),
        switcher.agents[2].id,
      );
    });

    test('setCurrentIndex ignores out-of-range values', () async {
      final switcher = AgentSwitcherProvider(
        settingsService: _FakeSettingsService(const Settings()),
        speechService: MockSpeechService(),
        providerFactory: makeMockProvider,
      );
      await switcher.initialize();

      await switcher.setCurrentIndex(99);
      expect(switcher.currentIndex, 0); // unchanged
    });

    test('switching agent index changes active ConversationProvider', () async {
      final switcher = AgentSwitcherProvider(
        settingsService: _FakeSettingsService(twoInstances),
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
        settingsService: _FakeSettingsService(const Settings()),
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
        settingsService: _FakeSettingsService(const Settings()),
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
        settingsService: _FakeSettingsService(twoInstances),
        speechService: MockSpeechService(),
        providerFactory: makeMockProvider,
      );
      await switcher.initialize();

      final p0 = switcher.providerFor(switcher.agents[0]);
      final p1 = switcher.providerFor(switcher.agents[1]);

      expect(identical(p0, p1), isFalse);
    });

    test('restores last active agent index from SharedPreferences', () async {
      final agents = twoInstances.allAgents;
      final targetId = agents[2].id; // third agent

      SharedPreferences.setMockInitialValues({
        'last_active_agent_id': targetId,
      });

      final switcher = AgentSwitcherProvider(
        settingsService: _FakeSettingsService(twoInstances),
        speechService: MockSpeechService(),
        providerFactory: makeMockProvider,
      );
      await switcher.initialize();

      expect(switcher.currentIndex, 2);
    });
  });
}
