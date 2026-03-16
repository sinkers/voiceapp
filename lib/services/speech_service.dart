import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _stt;
  bool _isInitialized = false;
  bool _hasReportedStop = false;

  SpeechService({SpeechToText? stt}) : _stt = stt ?? SpeechToText();

  Function(String finalText)? onFinalResult;
  Function(String partialText)? onPartialResult;
  Function()? onStopped;

  bool get isAvailable => _isInitialized;
  bool get isListening => _stt.isListening;

  @visibleForTesting
  bool get hasReportedStopForTesting => _hasReportedStop;

  @visibleForTesting
  void triggerStatusForTesting(String status) => _onStatus(status);

  Future<bool> initialize() async {
    _isInitialized = await _stt.initialize(
      onStatus: _onStatus,
      onError: _onError,
    );
    return _isInitialized;
  }

  Future<void> startListening() async {
    if (!_isInitialized) return;
    _hasReportedStop = false;
    await _stt.listen(
      onResult: _onResult,
      listenFor: const Duration(seconds: 55), // Stay under iOS 60s limit
      pauseFor: const Duration(seconds: 4),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: false,
      ),
    );
  }

  Future<void> stopListening() async {
    if (_stt.isListening) {
      await _stt.stop();
    }
  }

  Future<void> cancelListening() async {
    if (_stt.isListening) {
      await _stt.cancel();
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      onFinalResult?.call(result.recognizedWords);
    } else {
      onPartialResult?.call(result.recognizedWords);
    }
  }

  void _onStatus(String status) {
    if ((status == 'notListening' || status == 'done') && !_hasReportedStop) {
      _hasReportedStop = true;
      onStopped?.call();
    }
  }

  void _onError(dynamic error) {
    onStopped?.call();
  }

  void dispose() {
    _stt.cancel();
  }
}
