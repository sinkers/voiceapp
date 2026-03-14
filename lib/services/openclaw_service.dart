import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/settings.dart';

class OpenClawService {
  Future<List<String>> fetchAgents(OpenClawInstance instance) async {
    try {
      final base = instance.baseUrl.endsWith('/')
          ? instance.baseUrl.substring(0, instance.baseUrl.length - 1)
          : instance.baseUrl;
      final uri = Uri.parse('$base/models');
      final headers = <String, String>{};
      if (instance.token.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${instance.token}';
      }
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return ['main'];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final models = (data['data'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];

      final agents = models
          .map((m) => m['id'] as String? ?? '')
          .where((id) => id.startsWith('openclaw:') || id.startsWith('agent:'))
          .map((id) => id.substring(id.indexOf(':') + 1))
          .toList();

      return agents.isEmpty ? ['main'] : agents;
    } catch (e, s) {
      // ignore: avoid_print
      print('Failed to fetch OpenClaw agents: $e\n$s');
      return ['main'];
    }
  }
}
