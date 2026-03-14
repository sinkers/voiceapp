# TODO — voiceapp Code Review

---

## Branch: `feature/openclaw-agent-selection`

### 🐛 Bugs

#### ~~B1. Double `openclaw:` prefix on model string~~ ✅ Fixed in 43a1d2c
**File:** `lib/providers/conversation_provider.dart`

`fetchAgents()` returns IDs that already include the prefix (e.g. `openclaw:myagent`). But `_rebuildLlmService()` prepends it again:
```dart
model: 'openclaw:${_settings.selectedAgentId ?? 'main'}',
```
Result: model becomes `openclaw:openclaw:myagent` — broken for any non-default agent.

**Fix:** Strip the prefix when populating the agent list in `OpenClawService`, or drop the hardcoded prefix in `_rebuildLlmService()` and use the agent ID as-is.

```dart
// Option A — strip in OpenClawService:
final agents = models
    .map((m) => m['id'] as String? ?? '')
    .where((id) => id.startsWith('openclaw:') || id.startsWith('agent:'))
    .map((id) => id.replaceFirst(RegExp(r'^(openclaw:|agent:)'), ''))
    .toList();

// Option B — use as-is in provider (requires agents already have the prefix):
model: _settings.selectedAgentId ?? 'openclaw:main',
```

---

#### B2. Bearer token stored in plaintext JSON in SharedPreferences
**File:** `lib/services/settings_service.dart`, `lib/models/settings.dart`

`OpenClawInstance.toJson()` includes the token, which gets serialised to a plain JSON string in SharedPreferences. Same issue as main branch item #6, but worse — token is buried in a JSON blob making it harder to migrate later.

**Fix:** Exclude token from `toJson()` / `fromJson()`. Store per-instance tokens in `flutter_secure_storage` using key `openclaw_token_<instanceId>`. Load/save them separately in `SettingsService`.

```dart
// toJson — no token:
Map<String, dynamic> toJson() => {'id': id, 'name': name, 'baseUrl': baseUrl};

// SettingsService.save():
for (final instance in settings.openclawInstances) {
  if (instance.token.isNotEmpty) {
    await _secureStorage.write(
      key: 'openclaw_token_${instance.id}',
      value: instance.token,
    );
  }
}

// SettingsService.load():
for (final instance in openclawInstances) {
  final token = await _secureStorage.read(key: 'openclaw_token_${instance.id}') ?? '';
  // reassemble with token
}
```

---

#### B3. `_testInstance` shows a 60-second "Testing connection..." snackbar
**File:** `lib/screens/settings_screen.dart`

If the test completes quickly the stuck snackbar looks bad. If the user navigates away, it hangs for the full 60 seconds.

**Fix:** Use a short duration (e.g. 3s) and rely on `clearSnackBars()` when the result arrives.

```dart
const SnackBar(
  content: Text('Testing connection...'),
  duration: Duration(seconds: 3), // not 60
),
```

---

### ⚠️ Design Issues

#### ~~D1. No URL validation in `_InstanceFormDialog`~~ ✅ Fixed in 43a1d2c (inline Form validators)
**File:** `lib/screens/settings_screen.dart`

Only `name.isEmpty || url.isEmpty` is checked. An invalid URL silently passes through — `fetchAgents()` will throw and fall back to `['main']` with no user feedback.

**Fix:** Validate URL before enabling Save:
```dart
final uri = Uri.tryParse(url);
final isValidUrl = uri != null && uri.hasScheme && uri.host.isNotEmpty;
if (name.isEmpty || !isValidUrl) return;
```

---

#### D2. Agent selection reset is too aggressive
**File:** `lib/screens/settings_screen.dart`

Switching instances always clears `selectedAgentId` and resets to `agents.first`. If a user temporarily switches instances and returns, their previous agent choice is lost.

**Fix:** When switching back to a previously used instance, restore the last known agent selection. This requires tracking per-instance agent selection (a `Map<instanceId, agentId>` in Settings) rather than a single `selectedAgentId`.

---

#### D3. `_fetchAgentsForInstance` in `initState` not cancellable
**File:** `lib/screens/settings_screen.dart`

The HTTP fetch isn't tied to the widget lifecycle. The `mounted` guard prevents crashes, but the request runs to completion even if the screen is closed.

**Fix:** Store a `CancelToken` (if using `dio`) or simply accept the minor inefficiency given the 5s timeout. At minimum, set a flag on `dispose()` to skip any `setState` calls.

---

#### D4. `selectedInstance` getter uses two-step null check
**File:** `lib/models/settings.dart`

```dart
final matches = openclawInstances.where((i) => i.id == selectedInstanceId);
return matches.isEmpty ? null : matches.first;
```

**Fix:** Use `firstWhereOrNull` from the `collection` package (already a transitive dep via Flutter):
```dart
import 'package:collection/collection.dart';
return openclawInstances.firstWhereOrNull((i) => i.id == selectedInstanceId);
```

---

## 🐛 Bugs

### 1. `TtsService.reset()` doesn't stop active speech
**File:** `lib/services/tts_service.dart`

`reset()` sets `_isSpeaking = false` and clears the queue but never calls `_tts.stop()`. If a previous response is mid-sentence when a new LLM call starts, the old audio keeps playing. When it finishes, the completion handler fires and corrupts the new response's playback queue.

**Fix:** Make `reset()` async and call `await _tts.stop()` before clearing state. Update `_processWithLLM()` in `ConversationProvider` to `await _ttsService.reset()` at the top of the method.

```dart
Future<void> reset() async {
  await _tts.stop();
  _queue.clear();
  _isSpeaking = false;
  _finished = false;
  _doneCompleter = null;
}
```

---

### 2. Error banner dismiss is a no-op
**File:** `lib/screens/home_screen.dart`

`_ErrorBanner` has an `onDismiss` callback but it's wired as `() {}`. Errors are permanently visible until the next successful interaction.

**Fix:** Add a `clearError()` method to `ConversationProvider` that sets `_errorMessage = null` and calls `notifyListeners()`. Wire it to the banner's dismiss button.

```dart
// In ConversationProvider:
void clearError() {
  _errorMessage = null;
  notifyListeners();
}

// In HomeScreen:
_ErrorBanner(
  message: provider.errorMessage!,
  onDismiss: provider.clearError,
)
```

---

### 3. Both `_onSpeechFinal` and `_onSpeechStopped` can fire for the same utterance
**File:** `lib/services/speech_service.dart`, `lib/providers/conversation_provider.dart`

`_onStatus` fires for both `'notListening'` and `'done'` status strings, so `onStopped` can be called twice. The state guard in `ConversationProvider` catches it most of the time, but it's fragile.

**Fix:** Track a `_hasReportedStop` flag in `SpeechService` to ensure `onStopped` fires at most once per listen session. Reset it in `startListening()`.

```dart
bool _hasReportedStop = false;

Future<void> startListening() async {
  _hasReportedStop = false;
  // ... existing listen() call
}

void _onStatus(String status) {
  if ((status == 'notListening' || status == 'done') && !_hasReportedStop) {
    _hasReportedStop = true;
    onStopped?.call();
  }
}
```

---

## ⚠️ Design Issues

### 4. Can't interrupt during `processing` state
**File:** `lib/providers/conversation_provider.dart`

`toggleConversation()` does nothing while `_state == ConversationState.processing`. The user is stuck until speaking begins. There's also no way to cancel an in-flight LLM stream.

**Fix:** Hold a reference to the stream subscription and cancel it on interrupt. Handle the `processing` case in `toggleConversation()`.

```dart
StreamSubscription? _llmSubscription;

void toggleConversation() {
  switch (_state) {
    case ConversationState.idle:
      _startListening();
    case ConversationState.listening:
      _stopListeningAndProcess();
    case ConversationState.processing:
    case ConversationState.speaking:
      _interrupt();
  }
}

void _interrupt() {
  _llmSubscription?.cancel();
  _llmSubscription = null;
  _ttsService.stop();
  _speechService.cancelListening();
  // Clean up incomplete assistant message
  if (_messages.isNotEmpty && !_messages.last.isComplete) {
    _updateLastMessage(_messages.last.content, isComplete: true);
  }
  _setState(ConversationState.idle);
}
```

In `_processWithLLM()`, use `stream.listen(...)` with the subscription instead of `await for`.

---

### 5. `_scrollToBottom()` fires on every rebuild
**File:** `lib/screens/home_screen.dart`

`_scrollToBottom()` is called every time the `Consumer` rebuilds when messages exist — which during streaming is once per token. Each call schedules a `postFrameCallback`.

**Fix:** Track the previous message count and only scroll when it grows.

```dart
int _lastMessageCount = 0;

// In build():
if (provider.messages.length > _lastMessageCount) {
  _lastMessageCount = provider.messages.length;
  _scrollToBottom();
}
```

Note: you'll also want to scroll when the last message's content changes length (streaming). Consider tracking `provider.messages.lastOrNull?.content.length` too.

---

### 6. API keys stored in SharedPreferences (unencrypted)
**File:** `lib/services/settings_service.dart`

On Android, SharedPreferences are stored in plaintext XML. Anyone with USB debugging or root access can read the keys.

**Fix:** Use `flutter_secure_storage` for API key fields, keep non-sensitive settings in SharedPreferences.

```yaml
# pubspec.yaml
dependencies:
  flutter_secure_storage: ^9.0.0
```

```dart
// Store keys separately:
final _secureStorage = const FlutterSecureStorage();
await _secureStorage.write(key: 'claude_api_key', value: key);

// Load:
final key = await _secureStorage.read(key: 'claude_api_key');
```

---

### 7. `maxTokens: 4096` hardcoded in both LLM services
**Files:** `lib/services/claude_service.dart`, `lib/services/openai_service.dart`

Neither the user nor the system prompt can influence token budget. Some use cases (short voice replies) would benefit from a lower cap; others need more.

**Fix:** Add `maxTokens` to `Settings` with a sensible default, and pass it through `LLMService.streamResponse()` or the service constructor.

```dart
// Settings:
final int maxTokens; // default: 1024 for voice (responses should be short)

// LLMService interface:
Stream<String> streamResponse(List<Message> history, String systemPrompt, {int maxTokens = 1024});
```

---

## 🔧 Minor

### 8. Sentence splitter breaks on abbreviations
**File:** `lib/providers/conversation_provider.dart` — `_flushSentences()`

The regex `r'(?<=[.!?])\s+'` splits on any punctuation followed by whitespace. `"Dr. Smith"`, `"e.g. this"`, and `"U.S.A. is"` will all be split mid-sentence, causing awkward TTS pauses.

**Fix:** Only split when the punctuation is followed by whitespace and then an uppercase letter (heuristic for sentence starts).

```dart
final sentenceEnd = RegExp(r'(?<=[.!?])\s+(?=[A-Z"''\(])');
```

Not perfect, but much better for typical voice assistant responses.

---

### 9. TTS rate/pitch have no validation
**File:** `lib/models/settings.dart`

A corrupted or manually edited preferences file could persist `ttsRate: 0.0` or negative values, which get passed straight to the TTS engine.

**Fix:** Add clamping in `Settings.copyWith()` or in `SettingsService.load()`.

```dart
ttsRate: (ttsRate ?? this.ttsRate).clamp(0.1, 1.0),
ttsPitch: (ttsPitch ?? this.ttsPitch).clamp(0.5, 2.0),
```

---

### 10. `_onStatus` can fire `'notListening'` then `'done'` back-to-back
Covered by fix in item **#3** above.
