# CLAUDE.md

## Project

Flutter voice conversation app. Tap mic → STT → LLM (streaming) → TTS → repeat.

## Commands

```bash
flutter run                    # run on connected device/simulator
flutter analyze                # static analysis (must be zero issues)
flutter pub get                # install dependencies
flutter pub upgrade            # upgrade dependencies
```

## Architecture

State machine in `ConversationProvider`: `idle → listening → processing → speaking → idle`

- **`lib/providers/conversation_provider.dart`** — central orchestrator; owns the state machine and conversation loop
- **`lib/services/`** — one file per concern: `speech_service`, `tts_service`, `claude_service`, `openai_service`, `settings_service`
- **`lib/screens/`** — `home_screen` (main UI), `settings_screen`
- **`lib/widgets/`** — `mic_button`, `message_bubble`, `state_indicator`
- **`lib/models/`** — `Message`, `Settings`, `ConversationState` enum

## Key Design Decisions

**Sentence-buffered TTS**: The provider accumulates streaming text in `_textBuffer` and flushes complete sentences (split on `[.!?]\s+`) to the TTS queue as they arrive. Remaining text is flushed when the stream ends. This lets TTS start speaking before the LLM finishes. A 200-char fallback splits at the last space to prevent unbounded buffering on text with no punctuation.

**iOS 60s STT limit**: Handled by `pauseFor: 3s` (auto-stop on silence) and an `onStopped` callback that treats partial text as final if the session ends unexpectedly.

**LLM abstraction**: `LLMService` is an abstract interface with a single `Stream<String> streamResponse(history, systemPrompt)` method. `ClaudeService` and `OpenAIService` implement it. `ConversationProvider` rebuilds the active service whenever settings change.

**Interruption**: Tapping the mic button while in `speaking` state calls `_interrupt()`, which stops TTS and returns to `idle` without removing the (partially streamed) assistant message from history.

## SDK APIs

### anthropic_sdk_dart (^1.3.1)
```dart
final client = AnthropicClient.withApiKey(apiKey);
final stream = client.messages.createStream(MessageCreateRequest(
  model: model, maxTokens: 4096,
  system: SystemPrompt.text(systemPrompt),
  messages: [InputMessage.user(text), InputMessage.assistant(text), ...],
));
yield* stream.textDeltas(); // Stream<String>
client.close();
```

### openai_dart (^0.4.5)
```dart
final client = OpenAIClient(apiKey: apiKey, baseUrl: baseUrl);
final stream = client.createChatCompletionStream(request: CreateChatCompletionRequest(
  model: ChatCompletionModel.modelId(model),
  messages: [ChatCompletionMessage.system(content: ...), ChatCompletionMessage.user(...), ...],
));
// chunk.choices.first.delta.content → String?
client.endSession();
```

## OpenClaw Integration

The app connects to an OpenClaw gateway via the OpenAI-compatible API.

- **Base URL**: must include `/v1` — e.g. `http://10.3.0.41:18789/v1` (the `openai_dart` client appends `/chat/completions`, not `/v1/chat/completions`)
- **Model field**: `openclaw:<agentId>` — e.g. `openclaw:main`
- **System prompt**: suppressed when an OpenClaw instance is selected — the agent's own `SOUL.md`/`IDENTITY.md` takes over instead
- **Endpoint**: must be explicitly enabled in the gateway config: `gateway.http.endpoints.chatCompletions.enabled: true`
- **Network access**: gateway defaults to loopback — set `gateway.bind: "lan"` for LAN access from the phone

## Deploying to Physical Device (iOS)

Flutter's normal `flutter run -d <udid>` doesn't work reliably with newer Xcode/CoreDevice. Use this two-step flow instead:

```bash
# Build (use --profile to avoid debug dylib issues on iOS betas)
PATH="/tmp/sysctl_shim:$PATH" flutter build ios --profile

# Install via devicectl (get CoreDevice UUID from: xcrun devicectl list devices)
xcrun devicectl device install app --device <coredevice-uuid> build/ios/iphoneos/Runner.app
```

**sysctl shim** (needed in restricted shell environments where `sysctl` is missing):
```bash
mkdir -p /tmp/sysctl_shim && cat > /tmp/sysctl_shim/sysctl << 'EOF'
#!/bin/bash
if [[ "$*" == *"hw.optional.arm64"* ]]; then echo "1"; else /usr/sbin/sysctl "$@" 2>/dev/null || true; fi
EOF
chmod +x /tmp/sysctl_shim/sysctl
```

**Flutter channel**: repo uses `main` channel (upgraded from `stable` 3.41.4 to fix iOS 26 compatibility). Engine pre-cached with `flutter precache --ios`.

## Known Issues / iOS 26 Beta

- **VSyncClient crash on launch** (`EXC_BAD_ACCESS` in `createTouchRateCorrectionVSyncClientIfNeeded`): caused by `CADisableMinimumFrameDurationOnPhone=true` in `Info.plist` enabling ProMotion (120Hz), which triggers a broken `CADisplayLink` code path in the Flutter engine on iOS 26 beta. **Fixed** by setting it to `false` (locks to 60fps — fine for a voice app).
- **`flutter run` wireless**: phone appears in `flutter devices` but `xcodebuild` can't target it by old-style UDID on newer Xcode + CoreDevice. Use `devicectl` install flow above instead.
- **`audioplayers` 6.x**: `onPlayerStateChange` renamed to `onPlayerStateChanged`.

## Code Style

- Zero `flutter analyze` issues before committing
- Use `withValues(alpha: x)` not deprecated `withOpacity(x)`
- Use `CardThemeData` not `CardTheme` in `ThemeData`
- Prefer `const` constructors wherever possible
- No `print()` — use proper error propagation via provider error state
