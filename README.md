## FitGuru: An On-Device, Multi-Modal AI Workout Coach
The debug-apk and the release-apk is in the "releases" in our repo. To download it without any key, install the debug-apk. For production, we use the release apk.

### Status: Innovhacks 4.0 Submission
Platform: iOS (SwiftUI & WebKit), Android (Kotlin) & Web Companion

### Core Technologies: MediaPipe Pose, Wearable Sensor DataLayer, Android Room, On-Device GenAI

## Table of Contents

1. [Overview](#overview)
2. [Core Features](#core-features)
3. [System Architecture](#system-architecture)
4. [Tech Stack](#tech-stack)
5. [Project Structure](#project-structure)
6. [Setup and Installation](#setup-and-installation)
7. [System Requirements](#system-requirements)
8. [Engineering Decisions & Bottlenecks](#engineering-decisions--bottlenecks)
9. [Team Contribution](#team-contribution)
10. [DigitalOcean App Platform Deployment](#digitalocean-app-platform-deployment)

## Overview
FitGuru addresses a critical gap in the at-home fitness market: the lack of accessible, private, and intelligent coaching. While many apps track workouts, they fail to provide the real-time, expert feedback necessary for safe and effective exercise. Existing AI solutions often compromise user privacy by streaming sensitive camera data to the cloud.

FitGuru is a revolutionary application, built in Kotlin and modern Web technologies, that transforms a smartphone and wearable sensors into a seamless, on-device AI coaching system. By fusing real-time computer vision with live biometric data, FitGuru delivers an unparalleled, expert-level training experience with a 100% privacy-first guarantee.

## Core Features

- **Multi-Modal Form Coaching**  
  Real-time form analysis for multiple exercises (e.g., push-ups, squats), enriched with live heart rate data streamed directly from the Galaxy Watch.  

- **Automated Rep Counting**  
  Hands-free, accurate repetition counting using a state-machine logic built on body angle detection.  

- **Data-Driven Dashboard**  
  A personalized home screen showing live daily steps, calories (via Samsung Health), and dynamic daily challenges with progress toward weekly goals.  

- **Hands-Free Voice Feedback (Powered by ElevenLabs AI Voice Engine)**  
  Hyper-realistic, low-latency audio coaching powered by ElevenLabs conversational AI voice models (`eleven_turbo_v2_5`). Features customizable coach personas (e.g. *Coach Marcus* - Drill Sergeant, *Coach Maya* - Mindful Guide, *Coach Alex* - Olympian), multi-tier disk & RAM caching for 0ms repetitive rep feedback, and seamless automatic fallback to native on-device TTS.

- **Persistent Workout History**  
  Completed sessions are securely stored in an on-device Room database, enabling a detailed history view and profile with lifetime statistics.  

- **Login-Free Personalization**  
  Greets users by name using Android’s `ContactsContract`, delivering a personalized experience without requiring account creation.  

- **Multi-Model AI Model**
  Powered by `Gemma3b (1.3gb)` fully on-device LLM and a smart engine fallback ensuring 100 percent uptime and on-device privacy and security of data.

- **Biomechanical Form & Recovery Intelligence (Powered by Google Gemini API)**  
  Integrates **Google Gemini 2.5 Flash** (`gemini-2.5-flash`) to generate personalized kinematic breakdowns and post-workout recovery protocols. Translates measured joint angles and form telemetry into root-cause biomechanical diagnoses, 3 immediate corrective cues, accessory mobility drills, and targeted nutrition/hydration recovery timelines. Bridges directly into ElevenLabs AI voice synthesis for full spoken coach reviews.

- **Daily Updates**
  Keeps Calendar based updates of every data daily. Serving as a personal workout diary.

## 3. System Architecture

AuraFit is built as a high-performance, real-time data fusion system, optimized for **on-device execution** to guarantee privacy and offline reliability. At its core is our **Hybrid AI Engine** — a dual-model architecture that ensures maximum intelligence while guaranteeing **100% operational uptime**, even under strict mobile memory constraints.

![System Architecture](files/system_architecture.png)

### Data Fusion Pipeline

- **Parallel Inputs**  
  - **Camera Feed:** Processed by Google’s MediaPipe Pose Landmarker, extracting 33 skeletal keypoints per frame in real time.  
  - **Biometric Feed:** Handled by a custom `HealthDataManager` using Samsung Health Data SDK for live heart rate monitoring.  

- **On-Device Processing**  
  Both data streams are fused within the **Hybrid AI Engine**, enabling synchronized physical + biometric analysis without external servers.  

### The Hybrid AI Engine

- **Reflex Engine (Rule-Based AI)**  
  A lightweight, always-on engine running on every frame. It performs **instantaneous, critical tasks** such as rep counting and injury-prevention form alerts. Its efficiency ensures continuous operation regardless of system load.  

- **Cognitive Engine ("Plug-and-Play" LLM Slot)**  
  A deeper reasoning layer designed for **extensibility**. Any on-device generative model can be integrated. For our prototype, we deployed a 1.3GB Gemma LLM with a crash-proof pause/resume protocol: the camera stream briefly freezes to release memory, then resumes seamlessly once inference is complete.  

- **Smart Fallback (100% Uptime Guarantee)**  
  If the Cognitive Engine cannot load due to memory limits, the app **gracefully defaults** to the Reflex Engine without interruption. This **dual-AI architecture** ensures the coaching experience remains intact under all conditions — no crashes, no loss of functionality.  

### Unified Output

Actionable feedback is delivered through two synchronized channels:  
- **On-Screen Visuals** for clarity.  
- **Hands-Free Voice Coaching** via Android’s native Text-to-Speech for uninterrupted workouts.  

---


## 4. Tech Stack

- **Platform:**  
  Android (Kotlin-first), ensuring modern language features, strong tooling support, and seamless integration with Jetpack libraries.  

- **Vision AI Engine:**  
  Google MediaPipe Pose Landmarker (`tasks-vision:0.10.9`) for real-time, on-device body keypoint detection (33 landmarks per frame).  

- **Wearable Integration:**  
  Samsung Health Data SDK (`samsung-health-data-api-1.0.0.aar`) to stream live biometric signals (e.g., heart rate) from Galaxy Watch devices.  

- **Cognitive & Biomechanical AI Engines:**  
  - **Google Gemini API (`gemini-2.5-flash`):** High-throughput reasoning model powering personalized kinematic diagnosis, corrective motor cues, and metabolic recovery prescriptions.
  - **On-Device Gemma LLM & Cognitive Matrix:** Local fallback reasoning layer guaranteeing 100% operational uptime and zero cloud dependency when offline.

- **Data Persistence:**  
  Android Room Persistence Library for secure, structured, and offline-ready storage of workout history.  

- **UI & Architecture:**  
  Android Jetpack components (Fragments, Navigation) combined with **View Binding** and **Coroutines** for clean, responsive, and maintainable UI workflows.  

- **Voice Output & Audio Intelligence:**  
  **ElevenLabs Conversational AI Engine (`eleven_turbo_v2_5`)** with customizable coach personas (Drill Sergeant, Mindful Guide, Olympian) and local disk caching, paired with Native Text-to-Speech (iOS `AVSpeechSynthesizer` / Android TTS) for 100% offline fallback.

## 5. Project Structure

The AuraFit codebase is organized into a **modular and scalable structure**, separating core AI logic, UI, data management, and resources for maintainability.
```
samsung_genai/
├── app/
│ ├── build.gradle # App-level Gradle configuration
│ ├── libs/
│ │ └── samsung-health-data-api-1.0.0.aar # Samsung Health SDK
│ ├── local.properties
│ ├── proguard-rules.pro
│ ├── download_tasks.gradle
│ └── src/
│ ├── androidTest/ # Instrumented tests
│ ├── test/ # Unit tests
│ └── main/
│ ├── AndroidManifest.xml
│ ├── assets/
│ │ └── pose_landmarker_full.task # MediaPipe model
│ ├── jniLibs/ # Native libraries (if any)
│ ├── java/
│ │ └── com/google/mediapipe/examples/poselandmarker/
│ │ ├── data/ # Room DB entities, DAO, Database
│ │ │ ├── AppDatabase.kt
│ │ │ ├── Challenge.kt
│ │ │ ├── WorkoutDao.kt
│ │ │ └── WorkoutSession.kt
│ │ ├── fragment/ # UI Fragments
│ │ │ ├── CameraFragment.kt
│ │ │ ├── DashboardFragment.kt
│ │ │ ├── PermissionsFragment.kt
│ │ │ ├── ProfileFragment.kt
│ │ │ └── WorkoutsFragment.kt
│ │ ├── HealthDataManager.kt # Samsung Health SDK manager
│ │ ├── HistoryActivity.kt
│ │ ├── HistoryAdapter.kt
│ │ ├── MainActivity.kt
│ │ ├── MainViewModel.kt
│ │ ├── OverlayView.kt
│ │ ├── PoseLandmarkerHelper.kt
│ │ ├── SplashActivity.kt
│ │ └── WorkoutActivity.kt
│ └── res/
│ ├── color/
│ │ ├── bg_nav_item.xml
│ │ └── bottom_nav_color.xml
│ ├── drawable/ # Images, icons, shapes
│ ├── layout/ # XML layout files
│ │ ├── activity_history.xml
│ │ ├── activity_main.xml
│ │ ├── activity_splash.xml
│ │ ├── activity_workout.xml
│ │ ├── calendar_day.xml
│ │ ├── fragment_camera.xml
│ │ ├── fragment_dashboard.xml
│ │ ├── fragment_profile.xml
│ │ ├── fragment_workouts.xml
│ │ └── item_history_entry.xml
│ ├── menu/
│ │ ├── bottom_nav_menu.xml
│ │ └── menu_bottom_nav.xml
│ ├── mipmap-hdpi/
│ ├── mipmap-mdpi/
│ ├── mipmap-xhdpi/
│ ├── mipmap-xxhdpi/
│ ├── mipmap-xxxhdpi/
│ ├── navigation/ # Navigation graphs
│ └── values/ # Colors, strings, dimens
├── build/ # Gradle build outputs
├── gradle/
├── gradle.properties
├── gradlew*
├── gradlew.bat
├── local.properties
├── pose_landmarker.png
├── settings.gradle
└── build.gradle # Project-level Gradle configuration
```

---

###  Highlights

- **Modular Java/Kotlin code** under `com.google.mediapipe.examples.poselandmarker/` separates:
  - `data/` → Room database
  - `fragment/` → UI screens
  - Core activities and helpers (`MainActivity.kt`, `PoseLandmarkerHelper.kt`, `HealthDataManager.kt`)
- **Assets & Models**:
  - MediaPipe model (`pose_landmarker_full.task`) in `assets/`
- **Resources**:
  - Layouts, menus, colors, drawables, navigation graphs under `res/`
- **External Libraries**:
  - Samsung Health SDK in `app/libs/`
- **Branching Note**:
  - Samsung Health integration is implemented in the [`watch` branch](https://github.com/dagaayush1205/Samsung-GENAI-Hackathon/tree/watch)  

---

This version is **hierarchical, readable, and clearly separates modules**, making it perfect for a README.

---
## 6. Setup and Installation

### Prerequisites
- **Android Studio Iguana (or newer)**  
- **Physical Android device** running API 29 (Android 10) or higher  
- **Samsung Galaxy Watch** + **Samsung Health app** (required for full biometric functionality)  

### Steps
1. **Clone the repository**
   ```bash
   git clone https://github.com/dagaayush1205/Samsung-GENAI-Hackathon.git
   cd Samsung-GENAI-Hackathon

2. **Open the Project**
Launch **Android Studio** and open the cloned project directory.  

3. **Add Samsung Health SDK**
Ensure `samsung-health-data-api-1.0.0.aar` is placed in the `app/libs/` directory.  

4. **Sync Gradle Dependencies**
Allow Android Studio to complete the Gradle sync.  

5. **Run the App**
Connect your physical Android device and click **Run ▶️** in Android Studio.  

### Grant Permissions
On first launch, allow access to:
- Camera  
- Contacts  
- Samsung Health  


## 7. System Requirements

- **IDE:**  
  [Android Studio Iguana (2023.2.1) or later](https://developer.android.com/studio)  

- **Gradle JDK:**  
  The project is configured to build with **JVM 17**.  
  Ensure your Android Studio’s Gradle JDK is set to JDK 17 under:  
  `File > Settings > Build, Execution, Deployment > Build Tools > Gradle`  
  👉 [Download OpenJDK 17](https://adoptium.net/temurin/releases/?version=17)  

- **Target Device:**  
  A physical Android device running **API 29 (Android 10)** or higher.  
  *(Required by Samsung Health SDK for biometric integration.)*  

- **Samsung Health SDK:**  
  Download the Samsung Health Data SDK (`samsung-health-data-api-1.0.0.aar`) here:  
  🔗 [Samsung Health Data SDK](https://developer.samsung.com/health/android/data/overview.html)  

- **Cognitive AI Models (Optional for Cognitive Engine):**  
  AuraFit supports **plug-and-play on-device LLMs**. For our prototype, we integrated **Gemma 1.3B**.  
  - 🔗 [Gemma Models (Google AI)](https://ai.google.dev/gemma)  
  - 🔗 [Hugging Face Gemma Repository](https://huggingface.co/google/gemma)  
  - 🔗 [Other On-Device Models (Hugging Face Models Hub)](https://huggingface.co/models?library=transformers&sort=downloads)  

## 8. Engineering Decisions & Bottlenecks

During development, we faced several significant technical challenges. Our solutions to these problems became a core part of AuraFit’s innovation.  

---

### Decision: In-Place Refactoring vs. New Project
- **Challenge:** Starting from scratch would have meant weeks of boilerplate work configuring **CameraX + MediaPipe**.  
- **Decision:** We chose to build directly on the **official MediaPipe Pose Landmarker sample**, performing extensive **in-place refactoring**.  
- **Impact:** This gave us a **stable, production-ready camera + pose pipeline** from day one, allowing the team to focus on our **novel contributions** (UI, database, AI logic, wearable SDK integration). Development velocity increased dramatically.  

---

### Bottleneck: Samsung Health SDK Integration
- **Problem:** Samsung provides **multiple SDKs** (Data, Sensor, Accessory). Our initial attempt with the **Sensor SDK** led to build failures, unstable runtime behavior, and inconsistent API support.  
- **Solution:** We pivoted to the **Samsung Health Data SDK**, which is robust and officially documented.  
  - Built a modern **Kotlin-first `HealthDataManager.kt`** wrapper based on Samsung’s legacy Java examples.  
  - Implementation is currently maintained in the dedicated **[`watch` branch](https://github.com/dagaayush1205/Samsung-GENAI-Hackathon/tree/watch)** (not `main`).  
  - Achieved stable, reliable fetching of both **historical stats** and **live heart rate data** from the Galaxy Watch.  
- **Outcome:** A clean, extensible integration that future-proofs wearable data collection.  

---

### Bottleneck: On-Device LLM Memory Crashes
- **Ambition:** We aimed to integrate **Google’s Gemma 2B** as an on-device LLM for generative workout feedback.  
- **Problem:** Running the **1.3GB model** concurrently with a live camera feed caused **native memory crashes (SIGSEGV)** on typical Android devices.  
- **Solution:**  
  - Engineered a **Hybrid AI architecture** with a **pause/resume protocol**: the camera stream temporarily freezes to release memory, allowing the LLM to run safely.  
  - This worked. We tested it with the Gemma3b Model and also created a smart fallback Comprehensive Rule Based engine for 100% uptime.
  - **Outcome:** A **crash-proof Cognitive Engine design** that guarantees 100% uptime today, while paving the way for true on-device generative AI tomorrow.  

---

**Key Takeaway:**  
AuraFit’s biggest innovations came directly from solving these bottlenecks:  
- **Leveraging stable foundations** (MediaPipe sample refactoring)  
- **Building clean integrations** (Samsung Health Data SDK manager)  
- **Pioneering crash-proof AI architectures** (Hybrid Reflex + Cognitive engines with smart fallback)  

## 9. Team contributions

Our team's success was driven by a clear division of roles, allowing for rapid, parallel development of the app's complex components.

1. **Pavithra CP**- Engineered Core Application Structure and the Hybrid AI integration. Implemented pose landmarker from media pipe.
2. **Ayush Daga**- Integration of Samsung SDK. Worked in the `watch` branch to bring on the wearable and biometric support. Managed complex permission and connection lifestyle.
3. **Nikhil CP**- Worked with improving the UI and the User Experience. Improved the xml files and the fragments to bring an immersive experience. Implemented the Room Database for workout history and Persistence.
4. **Dhruv Gupta**- Helped with R&D and final integration and presentation. Vital role in testing, onboarding and error debugging for a flawless project.

Made with Love <3 
Team Astro Bugs (SRM IST, KTR)

---

## 10. DigitalOcean App Platform Deployment

FitGuru includes a lightweight, real-time **Web Companion** optimized for **DigitalOcean App Platform** so judges can test and experience the multi-modal AI coach instantly in their browser—without needing mobile hardware or local build toolchains.

[![Deploy to DO](https://www.deploytodo.com/do-btn-blue.svg)](https://cloud.digitalocean.com/apps/new?repo=https://github.com/atharvachaudhari1/innovhacks4.0-demo/tree/main)

### Deployment Options:

#### Option 1: DigitalOcean Web Console (Recommended for Judges)
1. Navigate to **[DigitalOcean App Platform](https://cloud.digitalocean.com/apps)**.
2. Click **Create App** and connect your GitHub repository.
3. DigitalOcean App Platform will automatically detect the [`.do/app.yaml`](.do/app.yaml) configuration and Node.js environment in `web-companion/`.
4. Click **Next** ➔ **Create Resource** to deploy with 1 click.

#### Option 2: DigitalOcean CLI (`doctl`)
```bash
# Authenticate doctl with your DigitalOcean API token
doctl auth init

# Deploy directly using the repository's App Platform spec
doctl apps create --spec .do/app.yaml
```

#### Option 3: Container Deployment (Docker)
A production-ready [`web-companion/Dockerfile`](web-companion/Dockerfile) is included for container deployments on DigitalOcean App Platform or Kubernetes:
```bash
cd web-companion
docker build -t fitguru-web-companion .
docker run -p 8080:8080 fitguru-web-companion
```

### Web Companion Capabilities for Evaluators:
- 📷 **In-Browser Vision AI**: Real-time webcam pose landmarking via MediaPipe for squats, push-ups, and lunges.
- 🧠 **Cognitive Biomechanics Matrix**: Live form correction and joint angle analytics.
- ⌚ **Galaxy Watch DataLayer Simulator**: Real-time biometric heart rate streaming and calorie telemetry.
- 📖 **20 Gym Equipment Database**: Comprehensive mechanical setup and mistake guides.
- 📥 **Mobile Artifact Hub**: One-click download for pre-built Android APKs and iOS build scripts.
