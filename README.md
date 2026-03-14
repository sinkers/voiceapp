# Voice Chat

A Flutter voice conversation app powered by Claude AI. Tap the mic, speak, and have a natural back-and-forth conversation with an AI assistant — fully spoken aloud.

## Features

- **Voice input** — native on-device speech recognition (iOS/Android)
- **Streaming AI responses** — text appears in real time as the model generates it
- **Natural TTS playback** — sentence-buffered text-to-speech starts speaking before the response finishes streaming
- **Full conversation context** — multi-turn memory throughout the session
- **Dual backend support** — Claude (Anthropic) or any OpenAI-compatible API (vLLM, OpenClaw, Ollama, etc.)
- **OpenClaw agent selection** — connect to an OpenClaw instance and pick which agent to talk to
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

### OpenClaw Integration

The app has first-class support for [OpenClaw](https://openclaw.ai) — connect to an instance and select which agent to talk to directly from Settings.

**How it works:**
1. In Settings, add an OpenClaw instance (base URL + optional bearer token)
2. The app fetches available agents from the instance's `/models` endpoint
3. Pick an agent — the app routes all conversations through it

**Accessing your OpenClaw instance from a phone:**

OpenClaw doesn't need to be publicly exposed. Options:

- **Same WiFi** — use the local IP directly (e.g. `http://192.168.1.x:18789/v1`). No setup needed.
- **Tailscale** *(recommended for remote access)* — install Tailscale on both the machine running OpenClaw and your phone. You get a private encrypted network; your phone can reach the Mac via a stable `100.x.x.x` address from anywhere, with no ports open to the internet. Free tier works fine.
- **Cloudflare Tunnel** — run `cloudflared` on the host machine. Creates an outbound-only HTTPS tunnel, no inbound ports or public IP needed. Can add access controls via Cloudflare Access.
- **ngrok / localtunnel** — quick to set up for testing, but URLs change on restart (unless on a paid plan).

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
