import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Returns an [http.Client] configured for the given [allowBadCertificate]
/// flag. When true, all TLS certificate errors are ignored — useful for
/// self-signed or otherwise invalid certs on local/dev OpenClaw instances.
///
/// ⚠️  Only enable this for trusted private network hosts.
http.Client buildHttpClient({bool allowBadCertificate = false}) {
  if (!allowBadCertificate) return http.Client();
  final ioClient = HttpClient()
    ..badCertificateCallback = (cert, host, port) => true;
  return IOClient(ioClient);
}
