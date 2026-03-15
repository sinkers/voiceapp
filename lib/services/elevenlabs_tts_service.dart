import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'tts_service.dart';

class ElevenLabsTtsService implements TtsService {
  final String apiKey;
  final String voiceId;
  final String modelId;

  final List<String> _queue = [];
  bool _isSpeaking = false;
  bool _finished = false;
  Completer<void>? _doneCompleter;
  AudioPlayer? _currentPlayer;

  @override
  Function()? onDone;

  ElevenLabsTtsService({
    required this.apiKey,
    required this.voiceId,
    required this.modelId,
  });

  @override
  Future<void> initialize({double rate = 0.5, double pitch = 1.0}) async {}

  @override
  void updateSettings(double rate, double pitch) {}

  @override
  void enqueue(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _queue.add(trimmed);
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
    final text = _queue.removeAt(0);
    _isSpeaking = true;
    _fetchAndPlay(text).then((_) {
      _isSpeaking = false;
      _playNext();
    }).catchError((Object e) {
      debugPrint('ElevenLabs TTS error: $e');
      _isSpeaking = false;
      _playNext();
    });
  }

  Future<void> _fetchAndPlay(String text) async {
    final response = await http.post(
      Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voiceId/stream'),
      headers: {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'text': text, 'model_id': modelId}),
    );
    if (!_isSpeaking) return;
    if (response.statusCode != 200) {
      throw Exception(
          'ElevenLabs API error: ${response.statusCode} ${response.body}');
    }
    await _playBytes(response.bodyBytes);
  }

  Future<void> _playBytes(Uint8List bytes) async {
    final tempFile = File(
      '${Directory.systemTemp.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    await tempFile.writeAsBytes(bytes);
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
      await _currentPlayer!.play(DeviceFileSource(tempFile.path));
      await stateCompleter.future;
    } finally {
      sub.cancel();
      await _currentPlayer?.dispose();
      _currentPlayer = null;
      try {
        await tempFile.delete();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _currentPlayer?.stop();
    _currentPlayer?.dispose();
    _currentPlayer = null;
  }
}
