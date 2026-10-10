# AGENTS.md — Agent Guidelines & Repository Architecture

Welcome to **FitGuru** (Innovhacks 4.0). This document serves as the primary guidance and operational reference for AI agents working in this repository.

---

## 1. Project Overview & Core Mission

**FitGuru** is an on-device, multi-modal AI workout coach that turns mobile devices and wearable sensors into a real-time, privacy-first personal fitness coach.

### Key Value Pillars
- **100% On-Device & Privacy-Preserving**: Camera frames, biometric data, and workout logs are analyzed locally. No user video or biometric telemetry is transmitted to external servers.
- **Multi-Modal Data Fusion**: Synchronizes live video input (MediaPipe Pose Landmarker) with wearable biometric signals (Samsung Health / Wearable DataLayer).
- **Hybrid AI Engine**:
  - **Reflex Engine**: Lightweight, frame-by-frame (30+ FPS) mathematical and rule-based angle calculations for instantaneous rep counting and posture/form correction.
  - **Cognitive Engine**: On-device LLM reasoning (Gemma) providing contextual feedback.
  - **Smart Fallback**: Graceful degradation to the Reflex Engine under strict memory pressure to ensure 100% operational uptime.

---

## 2. Repository Structure & Subsystems

```
Innohacks/
├── app/                  # Android Native Application (Kotlin)
│   ├── src/main/
│   │   ├── java/         # Activities, Fragments, Adapters, Room DB, MediaPipe helper
│   │   ├── res/          # Android Layouts, drawables, strings, navigation
│   │   └── AndroidManifest.xml
│   ├── build.gradle      # Android app-level Gradle build configuration
│   └── download_tasks.gradle
├── ios/                  # iOS Native Application (SwiftUI + WebKit)
│   ├── FitGuru/          # SwiftUI entry, Views, Native WebKit Bridge, Info.plist
│   ├── FitGuru.xcodeproj # Xcode Project configuration
│   ├── build_app.sh      # Automated build, package, and simulator run script
│   └── README.md
├── web-companion/        # Lightweight Web Companion (Node.js / Express)
│   ├── public/           # Static frontend interface and assets
│   └── server.js         # Express local server
├── files/                # Project diagrams and documentation assets
├── apk/                  # Pre-built release/debug APK binaries
├── README.md             # Comprehensive project documentation
└── AGENTS.md             # This file (Agent instructions & workspace guidelines)
```

---

## 3. Technology Stack & Key Dependencies

### Android (`/app`)
- **Language**: Kotlin
- **Vision AI**: Google MediaPipe Pose Landmarker (`tasks-vision:0.10.9`)
- **Architecture**: MVVM with Jetpack Navigation, ViewModels, and Fragments
- **Database**: Android Room (`AppDatabase`, `WorkoutDao`, `WorkoutSession`)
- **Camera**: AndroidX CameraX (Preview, ImageAnalysis)
- **Wearable Integration**: Samsung Health Data SDK (`samsung-health-data-api-1.0.0.aar`), Wearable DataLayer
- **Feedback**: Android Text-To-Speech (TTS)

### iOS (`/ios`)
- **Language**: Swift / SwiftUI
- **Frameworks**: SwiftUI, WebKit (`WKWebView`), AVFoundation (`AVAudioSession`), UIKit Haptics
- **Design Pattern**: Declarative SwiftUI lifecycle with embedded web engine bridge

### Web Companion (`/web-companion`)
- **Runtime**: Node.js & Express
- **Frontend**: Vanilla HTML5, CSS3, JavaScript

---

## 4. Development & Build Commands

### Android
- **Compile Debug APK**:
  ```bash
  ./gradlew assembleDebug
  ```
- **Run Unit Tests**:
  ```bash
  ./gradlew testDebugUnitTest
  ```
- **Lint / Code Analysis**:
  ```bash
  ./gradlew lintDebug
  ```

### iOS
- **Automated Compile & Simulator Launch**:
  ```bash
  ./ios/build_app.sh
  ```
- **Xcode CLI Build**:
  ```bash
  xcodebuild -project ios/FitGuru.xcodeproj -scheme FitGuru -destination 'platform=iOS Simulator,name=iPhone 16' build
  ```

### Web Companion
- **Install Dependencies**:
  ```bash
  cd web-companion && npm install
  ```
- **Start Local Server**:
  ```bash
  cd web-companion && npm start
  ```

---

## 5. Coding Conventions & Best Practices for Agents

### General Rules
1. **Preserve Privacy Invariants**: Under no circumstances should code be modified to stream raw camera frames or sensitive biometric user data to cloud endpoints.
2. **Preserve Existing Documentation**: Keep existing comments, license headers, and architecture docstrings intact.
3. **Graceful Error Handling**: Mobile resources (GPU, RAM, thermals) are constrained. Always implement fallbacks for heavy computations or memory-intensive ML tasks.

### Kotlin / Android (`/app`)
- Follow official Android Kotlin style guidelines.
- Use Kotlin Coroutines and structured concurrency (`viewModelScope`, `lifecycleScope`) for asynchronous tasks; avoid blocking the UI thread.
- Maintain Room database schema versioning: provide migration strategies when modifying database entities in `com.google.mediapipe.examples.poselandmarker.data`.
- Keep ViewModels decoupled from Android UI classes (`Context`, `View`).

### Swift / iOS (`/ios`)
- Follow modern Swift concurrency (`async/await`) and idiomatic declarative SwiftUI.
- Verify hardware permission entries (`NSCameraUsageDescription`, `NSMicrophoneUsageDescription`) in `Info.plist` when introducing hardware features.
- Ensure WKWebView configurations enforce local asset loading and proper message handler cleanup.

### Web Companion (`/web-companion`)
- Keep web UI lightweight, responsive, and cross-browser compatible.
- Maintain clear separation between server routes (`server.js`) and static frontend client files (`public/`).

---

## 6. Testing & Verification Checklist

Before finalizing changes, agents should verify:
- [ ] Code builds cleanly without introducing syntax or compile-time errors.
- [ ] No regression in core pose detection or rep-counting state machines.
- [ ] Database access remains thread-safe via Room DAOs.
- [ ] Assets and resource identifiers (layouts, drawables, strings, plists) exist and match references.
- [ ] Git status remains tidy and ignores build artifacts (e.g., `build/`, `.gradle/`, `DerivedData/`).
