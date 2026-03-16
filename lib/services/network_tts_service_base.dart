import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'on_device_tts_service.dart';
import 'tts_service.dart';

abstract class NetworkTtsServiceBase implements TtsService {
  final List<String> _queue = [];
  bool _isSpeaking = false;
  bool _finished = false;
  Completer<void>? _doneCompleter;
  AudioPlayer? _currentPlayer;
  OnDeviceTtsService? _fallbackTts;
  final Map<String, Future<Uint8List>> _prefetchCache = {};
  final http.Client _httpClient = http.Client();

  @override
  Function()? onDone;

  Future<Uint8List> fetchAudio(String text, http.Client client);

  /// MIME type of the audio returned by [fetchAudio]. Override in subclasses.
  String get audioMimeType => 'audio/mpeg';

  @visibleForTesting
  String sanitiseForTts(String text) {
    return text
        .replaceAll(RegExp(r'\.{2,}'), '')
        .replaceAll('…', '')
        .replaceAll('—', ', ')
        .replaceAll('–', ', ')
        .trim();
  }

  @override
  Future<void> initialize({double rate = 0.5, double pitch = 1.0}) async {
    _fallbackTts = OnDeviceTtsService();
    await _fallbackTts!.initialize(rate: rate, pitch: pitch);
  }

  @override
  void updateSettings(double rate, double pitch) {
    _fallbackTts?.updateSettings(rate, pitch);
  }

  @override
  void enqueue(String text) {
    final sanitised = sanitiseForTts(text);
    if (sanitised.isEmpty) return;
    _prefetchCache[sanitised] = fetchAudio(sanitised, _httpClient);
    _queue.add(sanitised);
    _playNext();
  }

  @override
  void markFinished() {
    _finished = true;
    if (!_isSpeaking && _queue.isEmpty) {
      _doneCompleter?.complete();
      onDone?.call();
    }
  }

  @override
  Future<void> waitUntilDone() {
    if (!_isSpeaking && _queue.isEmpty && _finished) {
      return Future.value();
    }
    _doneCompleter = Completer<void>();
    return _doneCompleter!.future;
  }

  @override
  Future<void> stop() async {
    _queue.clear();
    _prefetchCache.clear();
    _isSpeaking = false;
    _finished = false;
    if (!(_doneCompleter?.isCompleted ?? true)) {
      _doneCompleter?.complete();
    }
    _doneCompleter = null;
    await _currentPlayer?.stop();
    await _currentPlayer?.dispose();
    _currentPlayer = null;
  }

  @override
  Future<void> reset() async {
    _queue.clear();
    _prefetchCache.clear();
    _isSpeaking = false;
    _finished = false;
    _doneCompleter = null;
    await _currentPlayer?.stop();
    await _currentPlayer?.dispose();
    _currentPlayer = null;
  }

  void _playNext() {
    if (_isSpeaking || _queue.isEmpty) {
      if (!_isSpeaking && _queue.isEmpty && _finished) {
        if (!(_doneCompleter?.isCompleted ?? true)) {
          _doneCompleter?.complete();
        }
        onDone?.call();
      }
      return;
    }
    final text = _queue.removeAt(0);
    _isSpeaking = true;
    _fetchAndPlay(text).then((_) {
      _isSpeaking = false;
      _playNext();
    }).catchError((Object e) {
      debugPrint('Network TTS error: $e. Falling back to on-device TTS.');
      _fallbackToOnDevice(text);
    });
  }

  Future<void> _fetchAndPlay(String text) async {
    final bytes =
        await (_prefetchCache.remove(text) ?? fetchAudio(text, _httpClient));
    if (!_isSpeaking) return;
    await _playBytes(bytes, mimeType: audioMimeType);
  }

  void _fallbackToOnDevice(String text) {
    if (_fallbackTts != null) {
      _fallbackTts!.enqueue(text);
      _fallbackTts!.markFinished();
      _fallbackTts!.waitUntilDone().then((_) {
        _isSpeaking = false;
        _playNext();
      });
    } else {
      _isSpeaking = false;
      _playNext();
    }
  }

  Future<void> _playBytes(Uint8List bytes, {String? mimeType}) async {
    _currentPlayer = AudioPlayer();
    final stateCompleter = Completer<void>();
    StreamSubscription<PlayerState>? sub;
    sub = _currentPlayer!.onPlayerStateChanged.listen((state) {
      if ((state == PlayerState.completed || state == PlayerState.stopped) &&
          !stateCompleter.isCompleted) {
        sub?.cancel();
        stateCompleter.complete();
      }
    });
    try {
      await _currentPlayer!.play(BytesSource(bytes, mimeType: mimeType));
      await stateCompleter.future;
    } finally {
      sub.cancel();
      await _currentPlayer?.dispose();
      _currentPlayer = null;
    }
  }

  @override
  Future<void> dispose() async {
    await _currentPlayer?.stop();
    await _currentPlayer?.dispose();
    _currentPlayer = null;
    await _fallbackTts?.dispose();
    _httpClient.close();
  }
}
