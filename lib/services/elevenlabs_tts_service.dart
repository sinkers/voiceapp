import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'network_tts_service_base.dart';
import 'on_device_tts_service.dart';

class ElevenLabsTtsService extends NetworkTtsServiceBase {
  final String apiKey;
  final String voiceId;
  final String modelId;

  final List<String> _queue = [];
  bool _isSpeaking = false;
  bool _finished = false;
  Completer<void>? _doneCompleter;
  final Map<String, Future<Uint8List>> _prefetchCache = {};
  final http.Client _httpClient = http.Client();
  late final OnDeviceTtsService _fallbackTts;

  @override
  Function()? onDone;

  ElevenLabsTtsService({
    required this.apiKey,
    required this.voiceId,
    required this.modelId,
  }) {
    _fallbackTts = OnDeviceTtsService();
  }

  @override
  Future<void> initialize({double rate = 0.5, double pitch = 1.0}) async {
    await _fallbackTts.initialize(rate: rate, pitch: pitch);
  }

  @override
  void updateSettings(double rate, double pitch) {}

  @override
  void enqueue(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _prefetchCache[trimmed] = _fetchAudio(trimmed);
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
    _prefetchCache.clear();
    await currentPlayer?.stop();
    await currentPlayer?.dispose();
    disposePlayer();
  }

  @override
  void reset() {
    _queue.clear();
    _isSpeaking = false;
    _finished = false;
    _doneCompleter = null;
    _prefetchCache.clear();
    currentPlayer?.stop();
    currentPlayer?.dispose();
    disposePlayer();
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

  Future<Uint8List> _fetchAudio(String text) async {
    final response = await _httpClient.post(
      Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voiceId/stream'),
      headers: {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'model_id': modelId,
        'optimize_streaming_latency': 3,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
          'ElevenLabs API error: ${response.statusCode} ${response.body}');
    }
    return response.bodyBytes;
  }

  Future<void> _fetchAndPlay(String text) async {
    try {
      final bytes = await (_prefetchCache.remove(text) ?? _fetchAudio(text));
      if (!_isSpeaking) return;
      await playBytes(bytes);
    } catch (e) {
      debugPrint('ElevenLabs TTS network error: $e. Falling back to on-device TTS.');
      if (!_isSpeaking) return;
      _fallbackTts.enqueue(text);
      await _fallbackTts.waitUntilDone();
    }
  }

  @override
  void dispose() {
    _httpClient.close();
    _fallbackTts.dispose();
    disposePlayer();
  }
}
