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
  final SpeechService _speechService;

  /// Optional factory for creating [ConversationProvider] instances.
  /// Primarily useful for testing; defaults to the real implementation.
  final ConversationProvider Function()? _providerFactory;

  Settings _settings = const Settings();
  final Map<String, ConversationProvider> _providers = {};
  int _currentIndex = 0;
  bool _initialized = false;

  AgentSwitcherProvider({
    required SettingsService settingsService,
    required SpeechService speechService,
    ConversationProvider Function()? providerFactory,
  })  : _settingsService = settingsService,
        _speechService = speechService,
        _providerFactory = providerFactory;

  List<AgentConfig> get agents => _settings.allAgents;
  int get currentIndex => _currentIndex;
  Settings get settings => _settings;
  bool get initialized => _initialized;

  /// Returns the [ConversationProvider] for [agent], creating it lazily.
  ConversationProvider providerFor(AgentConfig agent) {
    return _providers.putIfAbsent(agent.id, () {
      final provider = _providerFactory != null
          ? _providerFactory()
          : ConversationProvider(
              speechService: _speechService,
              settingsService: _settingsService,
            );
      _initProviderForAgent(provider, agent);
      return provider;
    });
  }

  void _initProviderForAgent(ConversationProvider provider, AgentConfig agent) {
    // Build agent-specific settings by applying agent config to base settings
    Settings agentSettings;
    switch (agent) {
      case OpenClawAgentConfig(:final instance, :final agentId):
        agentSettings = _settings.copyWith(
          backend: LLMBackend.openaiCompatible,
          selectedInstanceId: instance.id,
          selectedAgentId: agentId,
        );
      case DirectModelAgentConfig(:final backend):
        agentSettings = _settings.copyWith(
          backend: backend,
          clearSelectedInstanceId: true,
          clearSelectedAgentId: true,
        );
    }
    provider.initializeForAgent(agentSettings);
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
    // Rebuild providers that are already live with updated agent-specific settings
    for (final entry in _providers.entries) {
      final agent = agents.firstWhereOrNull((a) => a.id == entry.key);
      if (agent != null) {
        Settings agentSettings;
        switch (agent) {
          case OpenClawAgentConfig(:final instance, :final agentId):
            agentSettings = _settings.copyWith(
              backend: LLMBackend.openaiCompatible,
              selectedInstanceId: instance.id,
              selectedAgentId: agentId,
            );
          case DirectModelAgentConfig(:final backend):
            agentSettings = _settings.copyWith(
              backend: backend,
              clearSelectedInstanceId: true,
              clearSelectedAgentId: true,
            );
        }
        await entry.value.updateSettings(agentSettings);
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
