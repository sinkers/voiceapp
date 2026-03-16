import 'dart:convert';
import '../models/settings.dart';
import 'http_client_factory.dart';

class OpenClawService {
  Future<List<String>> fetchAgents(OpenClawInstance instance) async {
    final client = buildHttpClient(
      allowBadCertificate: instance.allowBadCertificate,
    );
    try {
      final base = instance.baseUrl.endsWith('/')
          ? instance.baseUrl.substring(0, instance.baseUrl.length - 1)
          : instance.baseUrl;
      final uri = Uri.parse('$base/models');
      final headers = <String, String>{};
      if (instance.token.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${instance.token}';
      }
      final response = await client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return ['openclaw:main'];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final models =
          (data['data'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
          [];

      final agents = models
          .map((m) => m['id'] as String? ?? '')
          .where((id) => id.startsWith('openclaw:') || id.startsWith('agent:'))
          .toList();

      return agents.isEmpty ? ['openclaw:main'] : agents;
    } catch (e, s) {
      // ignore: avoid_print
      print('Failed to fetch OpenClaw agents: $e\n$s');
      return ['openclaw:main'];
    } finally {
      client.close();
    }
  }
}
