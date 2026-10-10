# FitGuru for Apple iPhone (iOS)

A native iOS application for **FitGuru: On-Device Multi-Modal AI Workout Coach**, built with **SwiftUI**, **WebKit**, and native hardware integration (Camera, Audio, and Haptic feedback).

---

## Architecture & Features

- **SwiftUI Lifecycle**: Modern declarative iOS app structure ([`FitGuruApp.swift`](FitGuru/FitGuruApp.swift)).
- **WebKit Native Bridge**: Embedded high-performance [`WebView.swift`](FitGuru/WebView.swift) loading on-device bundled assets with camera and audio hardware permissions granted.
- **Haptic Feedback**: Native `UIImpactFeedbackGenerator` and `UINotificationFeedbackGenerator` triggers on repetition counting and workout milestones.
- **AVAudioSession**: Real-time voice coaching cues configured for background mixing and audio playback.
- **On-Device Offline Bundled**: Pre-packaged HTML, CSS, JavaScript, and asset files in the app bundle.
- **Full-Screen iPhone Layout**: Automatically adapts to dynamic island, safe area insets, and iOS notch displays.

---

## Project Structure

```
ios/
├── FitGuru.xcodeproj/       # Xcode Project for building in Xcode
│   └── project.pbxproj
├── FitGuru/
│   ├── FitGuruApp.swift     # @main SwiftUI entry point
│   ├── ContentView.swift    # Root SwiftUI view
│   ├── WebView.swift        # WKWebView native bridge & delegates
│   ├── Info.plist           # Camera, Mic, and App permissions
│   ├── Assets.xcassets/     # App icons and asset catalog
│   └── Web/                 # Bundled workout engine & UI assets
└── build_app.sh             # Automated compile, bundle, and simulator deploy script
```

---

## How to Run

### Option 1: Automated Script (Fastest)

Run the automated script to compile, bundle, install, and launch directly on your active Apple Simulator:

```bash
./ios/build_app.sh
```

### Option 2: Open in Xcode

1. Open the project in Xcode:
   ```bash
   open ios/FitGuru.xcodeproj
   ```
2. Select your target device (e.g., **iPhone 17** simulator or connected iPhone).
3. Press **Cmd + R** (or click the **Play** button) to build and run.

---

## Permissions Configured (`Info.plist`)

- `NSCameraUsageDescription`: Required for on-device real-time AI pose detection and workout form analysis.
- `NSMicrophoneUsageDescription`: Required for voice commands and hands-free coaching.
- `NSAppTransportSecurity`: Local networking enabled for development companion syncing.
