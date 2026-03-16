/// An agent available on an OpenClaw gateway instance.
class OpenClawAgent {
  final String id;
  final String displayName;

  const OpenClawAgent({required this.id, required this.displayName});

  @override
  String toString() => 'OpenClawAgent(id: $id, displayName: $displayName)';
}
