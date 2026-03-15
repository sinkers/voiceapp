import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'tts_service.dart';

abstract class NetworkTtsServiceBase implements TtsService {
  AudioPlayer? _currentPlayer;

  AudioPlayer? get currentPlayer => _currentPlayer;

  Future<void> playBytes(Uint8List bytes) async {
    final tempFile = File(
      '${Directory.systemTemp.path}/tts_${const Uuid().v4()}.mp3',
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

  void disposePlayer() {
    _currentPlayer?.stop();
    _currentPlayer?.dispose();
    _currentPlayer = null;
  }
}
