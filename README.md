# Voice Chat

A Flutter voice conversation app powered by Claude AI. Tap the mic, speak, and have a natural back-and-forth conversation with an AI assistant — fully spoken aloud.

## Features

- **Voice input** — native on-device speech recognition (iOS/Android)
- **Streaming AI responses** — text appears in real time as the model generates it
- **Natural TTS playback** — sentence-buffered text-to-speech starts speaking before the response finishes streaming
- **Full conversation context** — multi-turn memory throughout the session
- **Dual backend support** — Claude (Anthropic) or any OpenAI-compatible API (vLLM, OpenClaw, Ollama, etc.)
- **Interrupt at any time** — tap the mic button while speaking to stop playback
- **Persistent settings** — API keys, model names, system prompt, and TTS tuning saved between sessions

## Setup

### Prerequisites

- Flutter 3.24+
- Xcode (for iOS) or Android Studio (for Android)
- An Anthropic API key, or access to an OpenAI-compatible endpoint

### Run

```bash
flutter pub get
flutter run
```

On first launch, tap the gear icon to open Settings and enter your API key.

## Settings

| Setting | Description |
|---------|-------------|
| **Provider** | Claude or OpenAI-compatible |
| **API Key** | Your Anthropic or OpenAI key |
| **Base URL** | Custom endpoint (e.g. `http://localhost:8000/v1` for vLLM) |
| **Model** | Model name (e.g. `claude-opus-4-6`, `gpt-4o`, `meta-llama/...`) |
| **System Prompt** | Instructions sent at the start of every conversation |
| **Speech Rate / Pitch** | TTS voice tuning |

### OpenAI-Compatible Backends

Any OpenAI-compatible server works by setting the Base URL:

- **vLLM**: `http://localhost:8000/v1`
- **OpenClaw**: `http://localhost:3000/v1`
- **Ollama**: `http://localhost:11434/v1`
- **OpenAI**: `https://api.openai.com/v1` (default)

## Architecture

```
[Mic Button tap]
      │
      ▼
[SpeechService]        ← native iOS/Android STT
      │ final transcript
      ▼
[ConversationProvider] ← state machine: idle→listening→processing→speaking→idle
      │ history + system prompt
      ▼
[ClaudeService /        ← streaming SSE
 OpenAIService]
      │ text deltas
      ▼
[TtsService]           ← sentence queue, plays while streaming continues
      │ done
      ▼
[idle — ready for next turn]
```

### Key packages

| Package | Purpose |
|---------|---------|
| `speech_to_text` | Native on-device STT |
| `flutter_tts` | On-device TTS |
| `anthropic_sdk_dart` | Claude streaming API |
| `openai_dart` | OpenAI-compatible streaming |
| `provider` | State management |
| `shared_preferences` | Settings persistence |

## Platform Notes

### iOS
- Requires `NSSpeechRecognitionUsageDescription` and `NSMicrophoneUsageDescription` in `Info.plist` (already configured)
- Apple enforces a 60-second STT session limit — the app handles this via `pauseFor` silence detection

### Android
- Requires `RECORD_AUDIO` and `INTERNET` permissions (already configured)
- `minSdkVersion` set to 21 (Android 5.0+)
