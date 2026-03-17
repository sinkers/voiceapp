import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/agent_config.dart';
import '../models/conversation_state.dart';
import '../models/message.dart';
import '../models/settings.dart';
import '../models/voice_config.dart';
import '../services/claude_service.dart';
import '../services/elevenlabs_tts_service.dart';
import '../services/llm_service.dart';
import '../services/on_device_tts_service.dart';
import '../services/openai_service.dart';
import '../services/openai_tts_service.dart';
import '../services/settings_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';

class ConversationProvider extends ChangeNotifier {
  final SpeechService _speechService;
  final SettingsService _settingsService;
  final _uuid = const Uuid();

  LLMService? _llmService;
  TtsService _ttsService;
  Settings _settings = const Settings();
  StreamSubscription<String>? _llmSubscription;
  Completer<void>? _llmCompleter;

  ConversationState _state = ConversationState.idle;
  List<Message> _messages = [];
  String _partialSttText = '';
  String _streamingText = '';
  String _textBuffer = '';
  String? _errorMessage;
  bool _initialized = false;

  ConversationProvider({
    required SpeechService speechService,
    required SettingsService settingsService,
    TtsService? ttsService,
  })  : _speechService = speechService,
        _settingsService = settingsService,
        _ttsService = ttsService ?? OnDeviceTtsService() {
    _speechService.onFinalResult = _onSpeechFinal;
    _speechService.onPartialResult = _onSpeechPartial;
    _speechService.onStopped = _onSpeechStopped;
  }

  /// Forces the conversation state — for testing only.
  @visibleForTesting
  void forceStateForTesting(ConversationState state) => _setState(state);

  // Getters
  ConversationState get state => _state;
  List<Message> get messages => List.unmodifiable(_messages);
  String get partialSttText => _partialSttText;
  Settings get settings => _settings;
  String? get errorMessage => _errorMessage;
  bool get initialized => _initialized;
  bool get hasApiKey => _llmService != null;
  bool get conversationalMode => _settings.conversationalMode;
  double get pauseDuration => _settings.pauseDuration;
  Duration get _pauseDuration =>
      Duration(milliseconds: (_settings.pauseDuration * 1000).round());

  Future<void> initialize() async {
    _settings = await _settingsService.load();
    final sttAvailable = await _speechService.initialize();
    if (!sttAvailable) {
      _errorMessage =
          'Speech recognition unavailable. Please enable microphone permission in Settings.';
    }
    await _rebuildTtsService();
    _rebuildLlmService();
    _initialized = true;
    notifyListeners();
  }

  /// Initialize with agent-specific settings WITHOUT persisting to SharedPreferences.
  /// Used by [AgentSwitcherProvider] to configure per-agent providers.
  Future<void> initializeForAgent(Settings agentSettings) async {
    _settings = agentSettings;
    final sttAvailable = await _speechService.initialize();
    if (!sttAvailable) {
      _errorMessage =
          'Speech recognition unavailable. Please enable microphone permission in Settings.';
    }
    await _rebuildTtsService();
    _rebuildLlmService();
    _initialized = true;
    notifyListeners();
  }

  /// Main entry point: tap mic button to start/stop/interrupt.
  void toggleConversation() {
    switch (_state) {
      case ConversationState.idle:
        _startListening();
      case ConversationState.listening:
        _stopListeningAndProcess();
      case ConversationState.processing:
      case ConversationState.speaking:
        _interrupt();
    }
  }

  void clearMessages() {
    _messages = [];
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Called from the Settings screen — persists to SharedPreferences.
  Future<void> updateSettings(Settings newSettings) async {
    _settings = newSettings;
    await _settingsService.save(newSettings);
    await _rebuildTtsService();
    _rebuildLlmService();
    notifyListeners();
  }

  /// Called from [AgentSwitcherProvider] — applies agent-specific settings
  /// WITHOUT persisting to SharedPreferences (avoid overwriting user prefs).
  Future<void> applyAgentSettings(Settings agentSettings) async {
    _settings = agentSettings;
    await _rebuildTtsService();
    _rebuildLlmService();
    notifyListeners();
  }

  void _startListening() {
    _errorMessage = null;
    _partialSttText = '';
    _setState(ConversationState.listening);
    _speechService.startListening(pauseDuration: _pauseDuration);
  }

  void _stopListeningAndProcess() {
    _speechService.stopListening();
    // onSpeechStopped will be called, which processes partial text
  }

  void _onSpeechPartial(String text) {
    // Barge-in: if in conversational mode and speaking, interrupt TTS
    if (_settings.conversationalMode &&
        _state == ConversationState.speaking &&
        text.trim().isNotEmpty) {
      // Stop TTS and LLM streaming, transition to listening.
      // _setState calls notifyListeners, so we update _partialSttText first
      // and return early to avoid a redundant notifyListeners call.
      _stopOutputStreams();
      _partialSttText = text;
      _setState(ConversationState.listening);
      return;
    }

    _partialSttText = text;
    notifyListeners();
  }

  void _onSpeechFinal(String text) {
    if (_state != ConversationState.listening) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _setState(ConversationState.idle);
      return;
    }
    _addUserMessage(trimmed);
    _processWithLLM();
  }

  void _onSpeechStopped() {
    if (_state != ConversationState.listening) return;
    final text = _partialSttText.trim();
    _partialSttText = '';
    if (text.isEmpty) {
      _setState(ConversationState.idle);
      return;
    }
    _addUserMessage(text);
    _processWithLLM();
  }

  void _addUserMessage(String text) {
    _messages = [
      ..._messages,
      Message(
        id: _uuid.v4(),
        role: MessageRole.user,
        content: text,
        timestamp: DateTime.now(),
        isComplete: true,
      ),
    ];
    _partialSttText = '';
    _setState(ConversationState.processing);
  }

  Future<void> _processWithLLM() async {
    if (_llmService == null) {
      _errorMessage = 'Please configure your API key in Settings.';
      _setState(ConversationState.idle);
      return;
    }

    // Add placeholder assistant message
    final assistantId = _uuid.v4();
    _messages = [
      ..._messages,
      Message(
        id: assistantId,
        role: MessageRole.assistant,
        content: '',
        timestamp: DateTime.now(),
        isComplete: false,
      ),
    ];
    _streamingText = '';
    _textBuffer = '';
    await _ttsService.reset();
    notifyListeners();

    try {
      final historyForLLM = _messages.sublist(0, _messages.length - 1);
      // When routing through an OpenClaw agent, suppress the app system prompt
      // so OpenClaw applies the agent's own persona (SOUL.md, IDENTITY.md, etc.)
      final selectedAgent = _settings.selectedAgent;
      final effectiveSystemPrompt = selectedAgent?.type == AgentType.openclaw
          ? ''
          : _settings.systemPrompt;
      final stream = _llmService!.streamResponse(
        historyForLLM,
        effectiveSystemPrompt,
      );

      bool firstChunk = true;
      final completer = Completer<void>();
      _llmCompleter = completer;
      _llmSubscription = stream.listen(
        (delta) {
          _streamingText += delta;
          _textBuffer += delta;

          // Update assistant message in place
          _updateLastMessage(_streamingText, isComplete: false);

          if (firstChunk) {
            _setState(ConversationState.speaking);
            // Start listening for barge-in in conversational mode
            if (_settings.conversationalMode) {
              _speechService.startListening(pauseDuration: _pauseDuration);
            }
            firstChunk = false;
          } else {
            notifyListeners();
          }

          // Extract complete sentences and send to TTS
          _flushSentences();
        },
        onDone: () {
          // Flush remaining buffer to TTS
          if (_textBuffer.trim().isNotEmpty) {
            _ttsService.enqueue(_textBuffer.trim());
            _textBuffer = '';
          }
          _ttsService.markFinished();

          // Mark message complete
          _updateLastMessage(_streamingText, isComplete: true);
          notifyListeners();

          if (!completer.isCompleted) completer.complete();
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        cancelOnError: true,
      );

      await completer.future;
      _llmCompleter = null;

      // If barge-in or interrupt stopped us while we were streaming, bail out.
      // _stopOutputStreams() already cancelled the subscription and stopped TTS;
      // the new turn (or idle state) will be managed by the caller.
      if (_state != ConversationState.speaking) {
        return;
      }

      // Wait for TTS to finish
      await _ttsService.waitUntilDone();

      // In conversational mode, automatically start listening again
      if (_settings.conversationalMode &&
          _state == ConversationState.speaking) {
        _speechService.cancelListening(); // cancel barge-in listener first
        _startListening(); // fresh listening session
        return;
      }
    } catch (e) {
      _llmCompleter = null;
      final errMsg = _friendlyError(e);
      _errorMessage = errMsg;
      if (_messages.isNotEmpty &&
          _messages.last.role == MessageRole.assistant &&
          !_messages.last.isComplete) {
        if (_messages.last.content.isEmpty) {
          // Remove empty assistant placeholder
          _messages = _messages.sublist(0, _messages.length - 1);
        } else {
          _updateLastMessage(_messages.last.content, isComplete: true);
        }
      }
    }

    _llmSubscription = null;
    _setState(ConversationState.idle);
  }

  void _flushSentences() {
    // Split at sentence boundaries (. ! ? followed by whitespace)
    final sentenceEnd = RegExp(r'(?<=[.!?])\s+');
    final matches = sentenceEnd.allMatches(_textBuffer).toList();
    if (matches.isEmpty) {
      // Fallback: flush at 200 chars if no sentence boundary found
      if (_textBuffer.length > 200) {
        final lastSpace = _textBuffer.lastIndexOf(' ');
        if (lastSpace > 0) {
          final chunk = _textBuffer.substring(0, lastSpace).trim();
          _textBuffer = _textBuffer.substring(lastSpace + 1);
          if (chunk.isNotEmpty) _ttsService.enqueue(chunk);
        }
      }
      return;
    }
    final lastMatch = matches.last;
    final completePart = _textBuffer.substring(0, lastMatch.end).trim();
    _textBuffer = _textBuffer.substring(lastMatch.end);
    if (completePart.isNotEmpty) {
      _ttsService.enqueue(completePart);
    }
  }

  void _stopOutputStreams() {
    _llmSubscription?.cancel();
    _llmSubscription = null;
    _ttsService.stop();
    // Unblock any _processWithLLM suspended at await completer.future so it
    // can exit cleanly instead of leaking the suspended async frame.
    _llmCompleter?.complete();
    _llmCompleter = null;
  }

  void _interrupt() {
    _stopOutputStreams();
    _speechService.cancelListening();
    _setState(ConversationState.idle);
  }

  void _updateLastMessage(String content, {required bool isComplete}) {
    if (_messages.isEmpty) return;
    final last = _messages.last;
    _messages = [
      ..._messages.sublist(0, _messages.length - 1),
      last.copyWith(content: content, isComplete: isComplete),
    ];
  }

  void _setState(ConversationState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> _rebuildTtsService() async {
    await _ttsService.dispose();

    // Get voice config from selected agent
    final selectedAgent = _settings.selectedAgent;
    if (selectedAgent == null) {
      // No agent selected - use default on-device TTS
      final svc = OnDeviceTtsService();
      await svc.initialize(rate: 0.5, pitch: 1.0);
      _ttsService = svc;
      return;
    }

    final voice = _settings.getVoiceById(selectedAgent.voiceId);
    if (voice == null) {
      // Voice not found - fall back to on-device
      final svc = OnDeviceTtsService();
      await svc.initialize(rate: 0.5, pitch: 1.0);
      _ttsService = svc;
      return;
    }

    switch (voice.provider) {
      case VoiceProvider.onDevice:
        final svc = OnDeviceTtsService();
        await svc.initialize(
          rate: voice.rate ?? 0.5,
          pitch: voice.pitch ?? 1.0,
        );
        _ttsService = svc;
      case VoiceProvider.elevenlabs:
        final svc = ElevenLabsTtsService(
          apiKey: voice.apiKey ?? '',
          voiceId: voice.voiceId ?? '21m00Tcm4TlvDq8ikWAM',
          modelId: voice.modelId ?? 'eleven_turbo_v2_5',
        );
        await svc.initialize();
        _ttsService = svc;
      case VoiceProvider.openai:
        final svc = OpenAITtsService(
          apiKey: voice.apiKey ?? '',
          voice: voice.voiceId ?? 'alloy',
          model: voice.modelId ?? 'tts-1',
        );
        await svc.initialize();
        _ttsService = svc;
    }
  }

  void _rebuildLlmService() {
    _llmService?.dispose();
    _llmService = null;

    final selectedAgent = _settings.selectedAgent;
    if (selectedAgent == null) {
      return;
    }

    switch (selectedAgent.type) {
      case AgentType.claude:
        final apiKey = selectedAgent.apiKey;
        if (apiKey != null && apiKey.isNotEmpty) {
          _llmService = ClaudeService(
            apiKey: apiKey,
            model: selectedAgent.model ?? 'claude-opus-4-6',
          );
        }
      case AgentType.openai:
        final apiKey = selectedAgent.apiKey;
        if (apiKey != null && apiKey.isNotEmpty) {
          _llmService = OpenAIService(
            apiKey: apiKey,
            baseUrl: selectedAgent.baseUrl ?? 'https://api.openai.com/v1',
            model: selectedAgent.model ?? 'gpt-4o',
          );
        }
      case AgentType.openclaw:
        final server = _settings.getServerById(selectedAgent.serverId ?? '');
        if (server != null) {
          // Use agent name as model ID with openclaw: prefix
          final modelId = selectedAgent.agentName != null &&
                  selectedAgent.agentName!.contains(':')
              ? selectedAgent.agentName!
              : 'openclaw:${selectedAgent.agentName ?? 'main'}';

          _llmService = OpenAIService(
            apiKey: server.token ?? '',
            baseUrl: server.baseUrl,
            model: modelId,
            customHeaders: {
              'x-openclaw-session-key':
                  const Uuid().v4(), // Generate session ID
            },
            allowBadCertificate: server.allowBadCertificate,
          );
        }
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('authentication')) {
      return 'Authentication failed. Please check your API key in Settings.';
    }
    if (msg.contains('429') || msg.contains('rate limit')) {
      return 'Rate limited. Please wait a moment and try again.';
    }
    if (msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('socket')) {
      return 'Network error. Please check your connection.';
    }
    return 'Error: $msg';
  }

  @override
  void dispose() {
    _llmSubscription?.cancel();
    _speechService.dispose();
    unawaited(_ttsService.dispose());
    _llmService?.dispose();
    super.dispose();
  }
}
