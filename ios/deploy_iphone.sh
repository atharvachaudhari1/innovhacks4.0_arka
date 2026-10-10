#!/usr/bin/env bash
set -e

DEVICE_ID="00008150-001839103C03C01C"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$DIR/.." && pwd)"

echo "==> Checking Allan's iPhone lock state..."
LOCK_STATE=$(xcrun devicectl device info lockState --device "$DEVICE_ID" 2>&1 || true)
if echo "$LOCK_STATE" | grep -q "passcodeRequired: true"; then
    echo "⚠️ Please unlock your iPhone with your passcode or Face ID to proceed with installation."
fi

echo "==> Building FitGuru for Allan's iPhone..."
xcodebuild -project "$DIR/FitGuru.xcodeproj" \
    -scheme FitGuru \
    -destination "id=$DEVICE_ID" \
    -allowProvisioningUpdates \
    build

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/FitGuru-*/Build/Products/Debug-iphoneos -name "FitGuru.app" -type d | head -n 1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Could not locate built FitGuru.app"
    exit 1
fi

echo "==> Installing FitGuru.app on Allan's iPhone..."
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

echo "==> Launching FitGuru on Allan's iPhone..."
xcrun devicectl device process launch --device "$DEVICE_ID" com.innovhacks.fitguru || true

echo "✅ FitGuru successfully updated and launched on your iPhone!"
