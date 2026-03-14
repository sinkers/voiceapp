import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _stt = SpeechToText();
  bool _isInitialized = false;

  Function(String finalText)? onFinalResult;
  Function(String partialText)? onPartialResult;
  Function()? onStopped;

  bool get isAvailable => _isInitialized;
  bool get isListening => _stt.isListening;

  Future<bool> initialize() async {
    _isInitialized = await _stt.initialize(
      onStatus: _onStatus,
      onError: _onError,
    );
    return _isInitialized;
  }

  Future<void> startListening() async {
    if (!_isInitialized) return;
    await _stt.listen(
      onResult: _onResult,
      listenFor: const Duration(seconds: 55), // Stay under iOS 60s limit
      pauseFor: const Duration(seconds: 3),
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
    if (status == 'notListening' || status == 'done') {
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
