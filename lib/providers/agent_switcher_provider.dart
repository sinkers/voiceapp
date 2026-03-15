import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agent_config.dart';
import '../models/settings.dart';
import '../services/settings_service.dart';
import '../services/speech_service.dart';
import 'conversation_provider.dart';

const _keyLastActiveAgentId = 'last_active_agent_id';

/// Top-level provider that manages the unified agent list, the active page
/// index, per-agent [ConversationProvider] instances, and settings persistence.
class AgentSwitcherProvider extends ChangeNotifier {
  final SettingsService _settingsService;

  /// Optional factory for creating [ConversationProvider] instances.
  /// Primarily useful for testing; defaults to the real implementation.
  final ConversationProvider Function()? _providerFactory;

  Settings _settings = const Settings();
  final Map<String, ConversationProvider> _providers = {};
  int _currentIndex = 0;
  bool _initialized = false;

  AgentSwitcherProvider({
    required SettingsService settingsService,
    ConversationProvider Function()? providerFactory,
  })  : _settingsService = settingsService,
        _providerFactory = providerFactory;

  List<AgentConfig> get agents => _settings.allAgents;
  int get currentIndex => _currentIndex;
  Settings get settings => _settings;
  bool get initialized => _initialized;

  /// Returns the [ConversationProvider] for [agent], creating it lazily.
  ConversationProvider providerFor(AgentConfig agent) {
    if (!_providers.containsKey(agent.id)) {
      final provider = _providerFactory != null
          ? _providerFactory!()
          : ConversationProvider(
              speechService: SpeechService(),
              settingsService: _settingsService,
            );
      _providers[agent.id] = provider;
      _initProviderForAgent(provider, agent);
    }
    return _providers[agent.id]!;
  }

  void _initProviderForAgent(ConversationProvider provider, AgentConfig agent) {
    provider.initialize().then((_) {
      if (!_providers.containsKey(agent.id)) return; // provider was disposed
      provider.applyAgentConfig(agent, _settings);
    });
  }

  Future<void> initialize() async {
    _settings = await _settingsService.load();
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString(_keyLastActiveAgentId);
    if (lastId != null) {
      final idx = agents.indexWhere((a) => a.id == lastId);
      if (idx >= 0) _currentIndex = idx;
    }
    _initialized = true;
    notifyListeners();
  }

  /// Persist new settings and refresh all existing per-agent providers.
  Future<void> updateSettings(Settings newSettings) async {
    _settings = newSettings;
    await _settingsService.save(newSettings);
    // Rebuild providers that are already live
    for (final entry in _providers.entries) {
      final agent = agents.firstWhereOrNull((a) => a.id == entry.key);
      if (agent != null) {
        await entry.value.applyAgentConfig(agent, _settings);
      }
    }
    notifyListeners();
  }

  Future<void> setCurrentIndex(int index) async {
    if (index < 0 || index >= agents.length) return;
    _currentIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastActiveAgentId, agents[index].id);
    notifyListeners();
  }

  @override
  void dispose() {
    for (final provider in _providers.values) {
      provider.dispose();
    }
    super.dispose();
  }
}

// Helper so we don't need to import collection everywhere.
extension _ListFirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
