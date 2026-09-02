#!/bin/bash
set -e
U=$(id -u)
LABEL=com.elrocie.mos-mouse-watcher
launchctl bootout "gui/$U/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Library/Application Support/mos-mouse-watcher"
echo "Removed the watcher, its LaunchAgent, and the binary."
echo "Log kept at ~/Library/Logs/mos-mouse-watcher.log (delete manually if you want)."
echo "MOS itself is untouched; re-enable its own 'Launch at login' if you want it back."
