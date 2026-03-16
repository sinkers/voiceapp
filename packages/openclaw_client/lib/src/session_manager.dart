import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates and manages session keys for OpenClaw gateway connections.
class SessionManager {
  /// Returns a new random session ID (UUID v4).
  static String newSessionId() => _uuid.v4();
}
