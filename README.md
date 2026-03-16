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

**OpenClaw instance setup:**

For the app to discover available agents automatically, the OpenClaw instance needs two things enabled:

**1. Chat completions endpoint** — in `openclaw.json`:
```json
"gateway": {
  "bind": "lan",
  "http": {
    "endpoints": {
      "chatCompletions": { "enabled": true }
    }
  }
}
```

**2. `agent-models` plugin** — exposes `GET /v1/models` returning configured agents in OpenAI format. Without this, the app falls back to `["main"]`.

Install steps:
```bash
# Create the plugin directory
mkdir -p ~/.openclaw/extensions/agent-models

# Create the plugin file: ~/.openclaw/extensions/agent-models/index.ts
cat > ~/.openclaw/extensions/agent-models/index.ts << 'PLUGIN'
import type { IncomingMessage, ServerResponse } from "http";
export default function register(api: any) {
  api.registerHttpRoute({
    path: "/v1/models",
    auth: "gateway",
    match: "exact",
    handler: async (req: IncomingMessage, res: ServerResponse) => {
      if (req.method !== "GET") {
        res.statusCode = 405;
        res.end(JSON.stringify({ error: { message: "Method not allowed" } }));
        return true;
      }
      const agents: Array<{ id: string }> = api.config?.agents?.list ?? [{ id: "main" }];
      const now = Math.floor(Date.now() / 1000);
      res.statusCode = 200;
      res.setHeader("Content-Type", "application/json");
      res.end(JSON.stringify({
        object: "list",
        data: agents.map(a => ({ id: `openclaw:${a.id}`, object: "model", created: now, owned_by: "openclaw" }))
      }));
      return true;
    }
  });
}
PLUGIN

# Create the plugin manifest: ~/.openclaw/extensions/agent-models/openclaw.plugin.json
cat > ~/.openclaw/extensions/agent-models/openclaw.plugin.json << 'MANIFEST'
{ "id": "agent-models", "name": "Agent Models", "description": "Exposes GET /v1/models returning configured agents" }
MANIFEST
```

Then enable it in `openclaw.json`:
```json
"plugins": {
  "allow": ["agent-models"],
  "entries": { "agent-models": { "enabled": true } }
}
```

Restart OpenClaw. Test with:
```bash
curl http://localhost:18789/v1/models -H "Authorization: Bearer <your-token>"
```


**Accessing your OpenClaw instance from a phone:**

OpenClaw doesn't need to be publicly exposed. Options:

- **Same WiFi** — use the local IP directly (e.g. `http://192.168.1.x:18789/v1`). No setup needed.
- **Tailscale** *(recommended for remote access)* — install Tailscale on both the machine running OpenClaw and your phone. You get a private encrypted network; your phone can reach the Mac via a stable `100.x.x.x` address from anywhere, with no ports open to the internet. Free tier works fine.
- **Cloudflare Tunnel** — run `cloudflared` on the host machine. Creates an outbound-only HTTPS tunnel, no inbound ports or public IP needed. Can add access controls via Cloudflare Access.
- **ngrok / localtunnel** — quick to set up for testing, but URLs change on restart (unless on a paid plan).

## Testing on Device

### iOS

**Requirements:** Mac with Xcode, Apple Developer account (free tier works), iPhone/iPad on iOS 14+

#### Option A: Build and install via Flutter CLI (recommended)

1. **Connect your phone** via USB and trust this computer if prompted.

2. **Build a development IPA** — use `--export-method development` (not the default App Store method, which requires a distribution certificate):
   ```bash
   flutter build ipa --release --export-method development \
     --dart-define=GIT_SHA=$(git rev-parse --short HEAD)
   ```
   Output: `build/ios/ipa/voiceapp.ipa`

3. **Install to device:**
   ```bash
   flutter install --device-id <your-device-id>
   ```
   To find your device ID: `flutter devices`

4. **Trust the cert on device** — Settings → General → VPN & Device Management → your Apple ID → Trust.

5. **Permissions** — mic and speech recognition prompts appear on first launch. Both are already configured in `Info.plist`.

> **Note:** Free developer accounts allow 3 installed apps max, and the cert expires after 7 days — just re-run the above commands to renew.

> **Why `--export-method development`?** The default `flutter build ipa` targets App Store distribution and requires an "iOS Distribution" certificate. For local device installs, `development` uses your standard dev cert which Xcode manages automatically.

#### Option B: Build and run directly via Xcode

1. **Open in Xcode** — always use the workspace, not the project file:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Set your Team** — Runner target → Signing & Capabilities → Team → pick your Apple ID. Xcode will manage provisioning automatically.

3. **Bundle ID** — currently `com.voiceapp.voiceapp`. If that conflicts with another app on your account, change it to something unique (e.g. `com.yourname.voiceapp`).

4. **Connect your phone**, select it as the run target, hit ⌘R.

---

### Android

**Requirements:** Android Studio (or SDK + `adb`), Android 5.0+ device (API 21+)

1. **Enable Developer Options** — Settings → About Phone → tap Build Number 7 times → back → Developer Options → enable USB Debugging.

2. **Connect via USB** and accept the debug prompt on the phone.

3. **Run:**
   ```bash
   flutter run --dart-define=GIT_SHA=$(git rev-parse --short HEAD)
   ```

4. **Or build a standalone APK:**
   ```bash
   flutter build apk --release --dart-define=GIT_SHA=$(git rev-parse --short HEAD)
   # Output: build/app/outputs/flutter-apk/app-release.apk
   ```
   Transfer to device and install (Settings → install unknown apps must be enabled).

5. **Wireless debugging (Android 11+)** — Settings → Developer Options → Wireless Debugging → pair device. Then `flutter run` works over WiFi with no cable.

6. **Permissions** — mic prompt appears on first use. Already declared in the manifest.

---

### Before You Test

- Have an API key ready (Claude or OpenAI) — required on first launch
- If testing the OpenClaw feature, have the instance URL and token handy
- iOS STT uses Apple's on-device recognition (works offline); Android STT may require internet depending on device and Android version

---

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
