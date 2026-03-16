import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'openclaw_agent.dart';
import 'openclaw_message.dart';

/// Thrown when an OpenClaw gateway returns an unexpected response.
class OpenClawException implements Exception {
  final String message;

  const OpenClawException(this.message);

  @override
  String toString() => 'OpenClawException: $message';
}

/// HTTP client for interacting with an OpenClaw gateway.
///
/// Supports agent discovery, single-turn completions, and streaming completions.
/// Set [allowBadCertificate] to `true` for gateways with self-signed TLS
/// certificates (not available on Flutter web).
class OpenClawClient {
  final String baseUrl;
  final String token;
  final bool allowBadCertificate;

  late final http.Client _httpClient;

  OpenClawClient({
    required this.baseUrl,
    this.token = '',
    this.allowBadCertificate = false,
    http.Client? httpClient,
  }) {
    if (httpClient != null) {
      _httpClient = httpClient;
    } else if (allowBadCertificate) {
      final ioClient = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      _httpClient = IOClient(ioClient);
    } else {
      _httpClient = http.Client();
    }
  }

  String get _base {
    final b = baseUrl;
    return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
  }

  Map<String, String> _headers({String? sessionKey}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (sessionKey != null && sessionKey.isNotEmpty) {
      headers['x-openclaw-session-key'] = sessionKey;
    }
    return headers;
  }

  /// Fetches the list of agents available on this gateway instance.
  ///
  /// Calls `GET /models` and filters results to entries whose IDs start with
  /// `openclaw:` or `agent:`. Falls back to `[openclaw:main]` on error or if
  /// no matching agents are found.
  Future<List<OpenClawAgent>> listAgents() async {
    final uri = Uri.parse('$_base/models');
    try {
      final response = await _httpClient.get(
        uri,
        headers: token.isNotEmpty ? {'Authorization': 'Bearer $token'} : {},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return _fallback();
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final models = (data['data'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];

      final agents = models
          .map((m) => m['id'] as String? ?? '')
          .where((id) =>
              id.startsWith('openclaw:') || id.startsWith('agent:'))
          .map((id) => OpenClawAgent(
                id: id,
                displayName: id.contains(':') ? id.split(':').last : id,
              ))
          .toList();

      return agents.isEmpty ? _fallback() : agents;
    } catch (e, s) {
      // ignore: avoid_print
      print('OpenClawClient error: $e\n$s');
      return _fallback();
    }
  }

  List<OpenClawAgent> _fallback() =>
      const [OpenClawAgent(id: 'openclaw:main', displayName: 'main')];

  /// Sends a single-turn chat completion request and returns the full response.
  Future<String> chatCompletion(
    String agentId,
    List<OpenClawMessage> messages, {
    String? sessionKey,
  }) async {
    final uri = Uri.parse('$_base/chat/completions');
    final body = jsonEncode({
      'model': agentId,
      'messages': messages.map((m) => m.toJson()).toList(),
    });

    final response = await _httpClient.post(
      uri,
      headers: _headers(sessionKey: sessionKey),
      body: body,
    );

    if (response.statusCode != 200) {
      throw OpenClawException(
          'HTTP ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) return '';
    return (choices.first as Map<String, dynamic>)['message']
            ?['content'] as String? ??
        '';
  }

  /// Sends a streaming chat completion request and yields text deltas.
  ///
  /// Parses the SSE response from `POST /chat/completions` with `stream: true`.
  Stream<String> streamChatCompletion(
    String agentId,
    List<OpenClawMessage> messages, {
    String? sessionKey,
  }) async* {
    final uri = Uri.parse('$_base/chat/completions');
    final request = http.Request('POST', uri)
      ..headers.addAll(_headers(sessionKey: sessionKey))
      ..body = jsonEncode({
        'model': agentId,
        'messages': messages.map((m) => m.toJson()).toList(),
        'stream': true,
      });

    final streamedResponse = await _httpClient.send(request);
    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      throw OpenClawException(
          'HTTP ${streamedResponse.statusCode}: $body');
    }

    final lines = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (!line.startsWith('data: ')) continue;
      final data = line.substring(6).trim();
      if (data == '[DONE]') break;
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final choices = json['choices'] as List?;
        if (choices == null || choices.isEmpty) continue;
        final delta = (choices.first as Map<String, dynamic>)['delta']
            ?['content'] as String?;
        if (delta != null) yield delta;
      } catch (e, s) {
      // ignore: avoid_print
      print('OpenClawClient error: $e\n$s');
        // Ignore malformed SSE lines.
      }
    }
  }

  /// Closes the underlying HTTP client.
  void close() => _httpClient.close();
}
