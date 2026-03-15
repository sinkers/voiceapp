import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'network_tts_service_base.dart';

class ElevenLabsTtsService extends NetworkTtsServiceBase {
  final String apiKey;
  final String voiceId;
  final String modelId;

  ElevenLabsTtsService({
    required this.apiKey,
    required this.voiceId,
    required this.modelId,
  });

  @override
  Future<Uint8List> fetchAudio(String text, http.Client client) async {
    final response = await client.post(
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
}
