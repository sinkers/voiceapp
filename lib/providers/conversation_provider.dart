import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/conversation_state.dart';
import '../models/message.dart';
import '../models/settings.dart';
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
  TtsService _ttsService = OnDeviceTtsService();
  Settings _settings = const Settings();

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
  })  : _speechService = speechService,
        _settingsService = settingsService {
    _speechService.onFinalResult = _onSpeechFinal;
    _speechService.onPartialResult = _onSpeechPartial;
    _speechService.onStopped = _onSpeechStopped;
  }

  // Getters
  ConversationState get state => _state;
  List<Message> get messages => List.unmodifiable(_messages);
  String get partialSttText => _partialSttText;
  Settings get settings => _settings;
  String? get errorMessage => _errorMessage;
  bool get initialized => _initialized;
  bool get hasApiKey => _llmService != null;

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

  /// Main entry point: tap mic button to start/stop/interrupt.
  void toggleConversation() {
    switch (_state) {
      case ConversationState.idle:
        _startListening();
      case ConversationState.listening:
        _stopListeningAndProcess();
      case ConversationState.speaking:
        _interrupt();
      case ConversationState.processing:
        // Do nothing while processing
        break;
    }
  }

  void clearMessages() {
    _messages = [];
    notifyListeners();
  }

  Future<void> updateSettings(Settings newSettings) async {
    _settings = newSettings;
    await _settingsService.save(newSettings);
    await _rebuildTtsService();
    _rebuildLlmService();
    notifyListeners();
  }

  void _startListening() {
    _errorMessage = null;
    _partialSttText = '';
    _setState(ConversationState.listening);
    _speechService.startListening();
  }

  void _stopListeningAndProcess() {
    _speechService.stopListening();
    // onSpeechStopped will be called, which processes partial text
  }

  void _onSpeechPartial(String text) {
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
    _ttsService.reset();
    notifyListeners();

    try {
      final historyForLLM = _messages.sublist(0, _messages.length - 1);
      // When routing through an OpenClaw agent, suppress the app system prompt
      // so OpenClaw applies the agent's own persona (SOUL.md, IDENTITY.md, etc.)
      final effectiveSystemPrompt =
          _settings.selectedInstance != null ? '' : _settings.systemPrompt;
      final stream = _llmService!.streamResponse(
        historyForLLM,
        effectiveSystemPrompt,
      );

      bool firstChunk = true;
      await for (final delta in stream) {
        _streamingText += delta;
        _textBuffer += delta;

        // Update assistant message in place
        _updateLastMessage(_streamingText, isComplete: false);

        if (firstChunk) {
          _setState(ConversationState.speaking);
          firstChunk = false;
        } else {
          notifyListeners();
        }

        // Extract complete sentences and send to TTS
        _flushSentences();
      }

      // Flush remaining buffer to TTS
      if (_textBuffer.trim().isNotEmpty) {
        _ttsService.enqueue(_textBuffer.trim());
        _textBuffer = '';
      }
      _ttsService.markFinished();

      // Mark message complete
      _updateLastMessage(_streamingText, isComplete: true);
      notifyListeners();

      // Wait for TTS to finish
      await _ttsService.waitUntilDone();
    } catch (e) {
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

  void _interrupt() {
    _ttsService.stop();
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
    _ttsService.dispose();
    switch (_settings.ttsProvider) {
      case TtsProvider.onDevice:
        final svc = OnDeviceTtsService();
        await svc.initialize(
            rate: _settings.ttsRate, pitch: _settings.ttsPitch);
        _ttsService = svc;
      case TtsProvider.elevenlabs:
        final svc = ElevenLabsTtsService(
          apiKey: _settings.elevenLabsApiKey ?? '',
          voiceId: _settings.elevenLabsVoiceId,
          modelId: _settings.elevenLabsModelId,
        );
        await svc.initialize();
        _ttsService = svc;
      case TtsProvider.openai:
        final svc = OpenAITtsService(
          apiKey: _settings.openaiApiKey ?? '',
          voice: _settings.openaiTtsVoice,
          model: _settings.openaiTtsModel,
        );
        await svc.initialize();
        _ttsService = svc;
    }
  }

  void _rebuildLlmService() {
    _llmService?.dispose();
    _llmService = null;

    if (_settings.backend == LLMBackend.claude) {
      final key = _settings.claudeApiKey;
      if (key != null && key.isNotEmpty) {
        _llmService = ClaudeService(
          apiKey: key,
          model: _settings.claudeModelName,
        );
      }
    } else {
      final instance = _settings.selectedInstance;
      if (instance != null) {
        _llmService = OpenAIService(
          apiKey: instance.token.isNotEmpty ? instance.token : 'no-key',
          baseUrl: instance.baseUrl,
          model: 'openclaw:${_settings.selectedAgentId ?? 'main'}',
        );
      } else {
        final key = _settings.openaiApiKey;
        if (key != null && key.isNotEmpty) {
          _llmService = OpenAIService(
            apiKey: key,
            baseUrl: _settings.openaiBaseUrl,
            model: _settings.openaiModelName,
          );
        }
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
    _speechService.dispose();
    _ttsService.dispose();
    _llmService?.dispose();
    super.dispose();
  }
}
