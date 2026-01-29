# Typester

[![Tests](https://github.com/nickustinov/typester-macos/actions/workflows/tests.yml/badge.svg)](https://github.com/nickustinov/typester-macos/actions/workflows/tests.yml)

A lightweight macOS menu bar app for speech-to-text dictation using [Soniox](https://soniox.com) or [Deepgram](https://deepgram.com).

![Demo](Assets/demo.gif)

## What it does

Typester lives in your menu bar and lets you dictate text directly into any application. Hold a key to speak or toggle recording with a hotkey — your words are automatically typed into the active text field.

**Bring Your Own Key (BYOK)** — Typester connects directly to your chosen speech-to-text provider using your own API key. No middleman, no subscription, no data collection. You pay only for what you use directly to the provider.

Features:
- **Multiple providers** — Choose between Soniox or Deepgram for speech recognition
- **Press-to-speak** — Hold the Fn key to dictate, release to paste (default mode)
- **Toggle mode** — Or use a global hotkey to start/stop recording (triple-tap ⌘⌘⌘ or custom shortcut)
- **Real-time transcription** — Uses streaming APIs for low-latency speech recognition
- **Multilingual** — Soniox: 60+ languages with hints; Deepgram: auto-detects with multilingual model
- **Microphone selection** — Choose your preferred input device from the menu
- **Custom dictionary** — Add domain-specific words, names, or technical terms (Soniox)
- **Auto-paste** — Transcribed text is automatically pasted into the active application
- **Secure API key storage** — Your API keys are stored in the macOS Keychain
- **Launch at login** — Start automatically when you log in

## Requirements

- macOS 13 or later
- API key from [Soniox](https://soniox.com) or [Deepgram](https://console.deepgram.com)

## Permissions

Typester requires two macOS permissions:

- **Microphone** — needed to capture your voice for transcription. Without this, the app cannot hear you speak.

- **Accessibility** — needed to paste transcribed text into other applications. Typester simulates ⌘V to insert text at your cursor position. Without this, transcription works but text won't be pasted automatically.

## Installation

1. Download `Typester-x.x.x.dmg` from Releases
2. Open the DMG and drag Typester to Applications
3. Launch from Applications — it appears as an icon in your menu bar
4. Follow the setup wizard to choose your provider and enter your API key
5. Grant Microphone and Accessibility permissions when prompted

## Usage

**Press-to-speak mode (default):**
1. Hold the Fn key
2. Speak — your words are transcribed in real-time
3. Release Fn — text is pasted into the active field

**Toggle mode:**
1. Press triple-Cmd (⌘⌘⌘) or your custom hotkey to start
2. Speak — your words appear in the active text field
3. Press the hotkey again to stop

You can switch between modes in Settings. Use the menu bar to select your microphone, preferred languages (Soniox only), or access settings.

## Building from source

**Debug build:**
```bash
swift build
swift run
```

**Release build (universal binary + DMG):**
```bash
./scripts/build-release.sh
```

This creates a universal binary (arm64 + x86_64), signs it if you have a Developer ID certificate, and packages it into a DMG at `dist/Typester-x.x.x.dmg`.

Requirements for building:
- Swift 5.9 or later
- Xcode Command Line Tools

## Development

**Debug logging:**
```bash
TYPESTER_DEBUG=1 swift run
```

**Reset app for fresh testing:**
```bash
# Reset permissions
tccutil reset Microphone com.typester.app
tccutil reset Accessibility com.typester.app

# Clear saved settings
defaults delete com.typester.app

# Remove API keys from keychain
security delete-generic-password -s "com.typester.api" -a "soniox-api-key"
security delete-generic-password -s "com.typester.api" -a "deepgram-api-key"
```

## Architecture

```
Sources/
├── main.swift                      # App entry point
└── TypesterCore/
    ├── AppDelegate.swift           # Status bar, menu, recording control
    ├── Models.swift                # Data models (ShortcutKeys, ActivationMode, etc.)
    ├── SettingsStore.swift         # UserDefaults + Keychain persistence
    ├── SettingsView.swift          # SwiftUI settings interface
    ├── OnboardingView.swift        # First-run setup wizard
    ├── HotkeyManager.swift         # Global hotkey registration (Carbon Events)
    ├── FnKeyMonitor.swift          # Fn key press-to-speak detection (CGEventTap)
    ├── AudioRecorder.swift         # AVAudioEngine microphone capture
    ├── STTProvider.swift           # Speech-to-text provider protocol
    ├── STTClientBase.swift         # Base class for STT WebSocket clients
    ├── SonioxClient.swift          # Soniox WebSocket streaming
    ├── DeepgramClient.swift        # Deepgram WebSocket streaming
    ├── TextPaster.swift            # Clipboard + simulated Cmd+V paste
    ├── KeyboardUtils.swift         # Key code to string conversion
    ├── AssetLoader.swift           # Asset path finding and loading
    └── Debug.swift                 # Debug logging utility

Tests/
├── ModelsTests.swift               # Model encoding/decoding tests
├── KeyboardUtilsTests.swift        # Keyboard utility tests
└── STTResponseParsingTests.swift   # STT response parsing tests
```

## Disclaimer

This project is not affiliated with, endorsed by, or sponsored by Soniox or Deepgram. These are third-party services used for speech recognition.

## License

MIT License

Copyright (c) 2026 Nick Ustinov

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
