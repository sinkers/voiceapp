import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  final List<String> _queue = [];
  bool _isSpeaking = false;
  bool _finished = false;
  Completer<void>? _doneCompleter;

  Function()? onDone;

  Future<void> initialize({double rate = 0.5, double pitch = 1.0}) async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.awaitSpeakCompletion(true);

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _playNext();
    });

    _tts.setErrorHandler((message) {
      _isSpeaking = false;
      _playNext();
    });
  }

  void updateSettings(double rate, double pitch) {
    _tts.setSpeechRate(rate);
    _tts.setPitch(pitch);
  }

  /// Enqueue a sentence for playback.
  void enqueue(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _queue.add(trimmed);
    _playNext();
  }

  /// Call when no more text will be enqueued. Once the queue drains, [waitUntilDone] completes.
  void markFinished() {
    _finished = true;
    if (!_isSpeaking && _queue.isEmpty) {
      _doneCompleter?.complete();
      onDone?.call();
    }
  }

  /// Returns a future that completes when all queued speech is done.
  Future<void> waitUntilDone() {
    if (!_isSpeaking && _queue.isEmpty && _finished) {
      return Future.value();
    }
    _doneCompleter = Completer<void>();
    return _doneCompleter!.future;
  }

  /// Immediately stop speaking and clear the queue.
  Future<void> stop() async {
    _queue.clear();
    _isSpeaking = false;
    _finished = false;
    if (!(_doneCompleter?.isCompleted ?? true)) {
      _doneCompleter?.complete();
    }
    _doneCompleter = null;
    await _tts.stop();
  }

  /// Reset state for a new response (without stopping active speech immediately).
  void reset() {
    _queue.clear();
    _isSpeaking = false;
    _finished = false;
    _doneCompleter = null;
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
    final sentence = _queue.removeAt(0);
    _isSpeaking = true;
    _tts.speak(sentence);
  }

  void dispose() {
    _tts.stop();
  }
}
