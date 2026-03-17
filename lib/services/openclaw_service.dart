import 'dart:convert';
import '../models/agent_config.dart';
import 'http_client_factory.dart';

class OpenClawService {
  Future<List<String>> fetchAgents(OpenClawServer server) async {
    final client = buildHttpClient(
      allowBadCertificate: server.allowBadCertificate,
    );
    try {
      final base = server.baseUrl.endsWith('/')
          ? server.baseUrl.substring(0, server.baseUrl.length - 1)
          : server.baseUrl;
      final uri = Uri.parse('$base/models');
      final headers = <String, String>{};
      if (server.token != null && server.token!.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${server.token}';
      }
      final response = await client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return ['main'];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final models =
          (data['data'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
              [];

      final agents = models
          .map((m) => m['id'] as String? ?? '')
          .where((id) => id.startsWith('openclaw:') || id.startsWith('agent:'))
          .map((id) {
            // Strip openclaw: or agent: prefix to get just the agent name
            if (id.startsWith('openclaw:')) {
              return id.substring('openclaw:'.length);
            } else if (id.startsWith('agent:')) {
              return id.substring('agent:'.length);
            }
            return id;
          })
          .toList();

      return agents.isEmpty ? ['main'] : agents;
    } catch (e, s) {
      // ignore: avoid_print
      print('Failed to fetch OpenClaw agents: $e\n$s');
      return ['main'];
    } finally {
      client.close();
    }
  }
}
