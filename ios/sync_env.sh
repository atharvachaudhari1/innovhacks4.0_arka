#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$DIR")"
SECRETS_PLIST="$DIR/FitGuru/Secrets.plist"

if [ -f "$PROJECT_ROOT/.env" ]; then
  ENV_KEY=$(grep -E "^ELEVENLABS_API_KEY=" "$PROJECT_ROOT/.env" | cut -d '=' -f2- | tr -d ' "\r\n')
  GEMINI_KEY=$(grep -E "^GEMINI_API_KEY=" "$PROJECT_ROOT/.env" | cut -d '=' -f2- | tr -d ' "\r\n')
  
  cat <<EOF > "$SECRETS_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>ELEVENLABS_API_KEY</key>
	<string>$ENV_KEY</string>
	<key>GEMINI_API_KEY</key>
	<string>$GEMINI_KEY</string>
</dict>
</plist>
EOF
  echo "==> Synced API keys to ios/FitGuru/Secrets.plist (git-ignored)."
fi
