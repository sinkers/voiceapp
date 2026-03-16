import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'network_tts_service_base.dart';

class OpenAITtsService extends NetworkTtsServiceBase {
  final String apiKey;
  final String voice;
  final String model;

  OpenAITtsService({
    required this.apiKey,
    required this.voice,
    required this.model,
  });

  @override
  Future<Uint8List> fetchAudio(String text, http.Client client) async {
    final response = await client.post(
      Uri.parse('https://api.openai.com/v1/audio/speech'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'model': model, 'input': text, 'voice': voice}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'OpenAI TTS error: ${response.statusCode} ${response.body}',
      );
    }
    return response.bodyBytes;
  }
}
