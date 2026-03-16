import 'package:openclaw_client/openclaw_client.dart';

class OpenClawService {
  Future<List<String>> fetchAgents(OpenClawInstance instance) async {
    final client = OpenClawClient(
      baseUrl: instance.baseUrl,
      token: instance.token,
      allowBadCertificate: instance.allowBadCertificate,
    );
    try {
      final agents = await client.listAgents();
      return agents.map((a) => a.id).toList();
    } finally {
      client.close();
    }
  }
}
