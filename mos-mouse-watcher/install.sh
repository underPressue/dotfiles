#!/bin/bash
set -e
U=$(id -u)
LABEL=com.elrocie.mos-mouse-watcher
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/Library/Application Support/mos-mouse-watcher"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$DEST" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cp "$SRC/main.swift" "$SRC/uninstall.sh" "$DEST/"
swiftc -O -o "$DEST/mos-mouse-watcher" "$DEST/main.swift"

cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$DEST/mos-mouse-watcher</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Background</string>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/mos-mouse-watcher.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/mos-mouse-watcher.log</string>
</dict>
</plist>
PLISTEOF

launchctl bootout "gui/$U/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$U" "$PLIST"
launchctl kickstart -k "gui/$U/$LABEL"
echo "Installed and started $LABEL."
