# openclaw_client

Dart client library for the [OpenClaw](https://github.com/sinkers/openclaw) AI gateway.

## Features

- **Agent discovery** — list available agents via `GET /models`
- **Chat completion** — single-turn `POST /chat/completions`
- **Streaming chat** — streaming `POST /chat/completions` with SSE parsing
- **Session keys** — per-connection `x-openclaw-session-key` header support
- **Self-signed TLS** — optional `allowBadCertificate` for local/dev gateways

## Usage

```dart
import 'package:openclaw_client/openclaw_client.dart';

// 1. Describe your gateway instance.
final instance = OpenClawInstance(
  id: 'my-pi',
  name: 'Home Pi',
  baseUrl: 'http://10.3.0.41:18789/v1',
  token: 'optional-bearer-token',
  sessionId: SessionManager.newSessionId(),
);

// 2. Create the client.
final client = OpenClawClient(
  baseUrl: instance.baseUrl,
  token: instance.token,
);

// 3. Discover agents.
final agents = await client.listAgents();
// → [OpenClawAgent(id: 'openclaw:main', displayName: 'main'), ...]

// 4. Single-turn completion.
final reply = await client.chatCompletion(
  'openclaw:main',
  [OpenClawMessage.user('Hello!')],
  sessionKey: instance.sessionId,
);

// 5. Streaming completion.
await for (final delta in client.streamChatCompletion(
  'openclaw:main',
  [OpenClawMessage.user('Tell me a story.')],
  sessionKey: instance.sessionId,
)) {
  stdout.write(delta);
}

client.close();
```

### Self-signed certificates

```dart
final client = OpenClawClient(
  baseUrl: 'https://192.168.1.100:18789/v1',
  allowBadCertificate: true, // not available on Flutter web
);
```

### Session management

```dart
// Generate a new UUID session ID.
final sessionId = SessionManager.newSessionId();
```

## Gateway setup

The OpenClaw gateway must have the chat completions endpoint enabled:

```yaml
gateway:
  http:
    endpoints:
      chatCompletions:
        enabled: true
  bind: lan  # allow LAN access from mobile
```

The model field must be `openclaw:<agentId>` (e.g. `openclaw:main`).
The base URL must include `/v1` — the client appends `/chat/completions` directly.
