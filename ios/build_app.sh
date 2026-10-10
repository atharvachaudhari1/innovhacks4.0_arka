#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$DIR")"
BUILD_DIR="/tmp/FitGuruBuild"
APP_BUNDLE="$BUILD_DIR/FitGuru.app"

echo "==> Preparing Build Directories..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$APP_BUNDLE"

SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)

echo "==> Compiling Swift Sources..."
xcrun --sdk iphonesimulator swiftc \
  -target arm64-apple-ios17.0-simulator \
  -sdk "$SDK_PATH" \
  -O \
  -framework SwiftUI \
  -framework WebKit \
  -framework AVFoundation \
  -framework Vision \
  -framework UIKit \
  -framework Speech \
  -framework AppIntents \
  "$DIR/FitGuru/Theme.swift" \
  "$DIR/FitGuru/Models.swift" \
  "$DIR/FitGuru/GymCatalogData.swift" \
  "$DIR/FitGuru/PoseEstimator.swift" \
  "$DIR/FitGuru/VoiceCommandManager.swift" \
  "$DIR/FitGuru/SiriIntents.swift" \
  "$DIR/FitGuru/SmartRestTimerSheet.swift" \
  "$DIR/FitGuru/AnalyticsDashboardView.swift" \
  "$DIR/FitGuru/PoseCoachView.swift" \
  "$DIR/FitGuru/DashboardView.swift" \
  "$DIR/FitGuru/WorkoutsView.swift" \
  "$DIR/FitGuru/ProfileView.swift" \
  "$DIR/FitGuru/EquipmentGuideSheet.swift" \
  "$DIR/FitGuru/HistoryView.swift" \
  "$DIR/FitGuru/ElevenLabsService.swift" \
  "$DIR/FitGuru/VoiceSettingsSheet.swift" \
  "$DIR/FitGuru/GeminiService.swift" \
  "$DIR/FitGuru/WorkoutSummarySheet.swift" \
  "$DIR/FitGuru/ContentView.swift" \
  "$DIR/FitGuru/WebView.swift" \
  "$DIR/FitGuru/FitGuruApp.swift" \
  -o "$APP_BUNDLE/FitGuru"

chmod +x "$APP_BUNDLE/FitGuru"

echo "==> Compiling Asset Catalog..."
xcrun actool "$DIR/FitGuru/Assets.xcassets" \
  --compile "$APP_BUNDLE" \
  --platform iphonesimulator \
  --minimum-deployment-target 17.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$BUILD_DIR/partial-info.plist"

echo "==> Copying Info.plist and Web Resources..."
cp "$DIR/FitGuru/Info.plist" "$APP_BUNDLE/Info.plist"
cp -r "$DIR/FitGuru/Web" "$APP_BUNDLE/Web"

if [ -f "$PROJECT_ROOT/.env" ]; then
  ENV_KEY=$(grep -E "^ELEVENLABS_API_KEY=" "$PROJECT_ROOT/.env" | cut -d '=' -f2- | tr -d ' "\r\n')
  if [ -n "$ENV_KEY" ]; then
    echo "==> Injecting ElevenLabs API Key from .env into app bundle..."
    /usr/libexec/PlistBuddy -c "Set :ELEVENLABS_API_KEY $ENV_KEY" "$APP_BUNDLE/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :ELEVENLABS_API_KEY string $ENV_KEY" "$APP_BUNDLE/Info.plist"
  fi

  GEMINI_KEY=$(grep -E "^GEMINI_API_KEY=" "$PROJECT_ROOT/.env" | cut -d '=' -f2- | tr -d ' "\r\n')
  if [ -n "$GEMINI_KEY" ]; then
    echo "==> Injecting Gemini API Key from .env into app bundle..."
    /usr/libexec/PlistBuddy -c "Set :GEMINI_API_KEY $GEMINI_KEY" "$APP_BUNDLE/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :GEMINI_API_KEY string $GEMINI_KEY" "$APP_BUNDLE/Info.plist"
  fi
fi

echo "==> Cleaning extended attributes..."
find "$BUILD_DIR" -exec xattr -c {} + 2>/dev/null || true
xattr -cr "$APP_BUNDLE" 2>/dev/null || true

echo "==> Code Signing Bundle..."
codesign -s - --force --deep "$APP_BUNDLE"

echo "==> FitGuru.app successfully built at: $APP_BUNDLE"

BOOTED_DEVICE=$(xcrun simctl list devices | grep -i "(Booted)" | head -n 1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')

if [ -n "$BOOTED_DEVICE" ]; then
  echo "==> Installing on Booted Simulator ($BOOTED_DEVICE)..."
  xcrun simctl install "$BOOTED_DEVICE" "$APP_BUNDLE"
  echo "==> Launching com.innovhacks.fitguru..."
  xcrun simctl launch "$BOOTED_DEVICE" com.innovhacks.fitguru
else
  echo "==> No booted simulator found. You can boot one with: xcrun simctl boot <device_id>"
fi
