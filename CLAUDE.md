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

## Code Style

- Zero `flutter analyze` issues before committing
- Use `withValues(alpha: x)` not deprecated `withOpacity(x)`
- Use `CardThemeData` not `CardTheme` in `ThemeData`
- Prefer `const` constructors wherever possible
- No `print()` — use proper error propagation via provider error state
