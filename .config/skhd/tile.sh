#!/usr/bin/env bash
# Tile frontmost window to left/right half via native macOS Window > Move & Resize menu
# Usage: tile.sh left|right

dir="$1"
case "$dir" in
  left)  names='{"Left", "Left Half"}' ;;
  right) names='{"Right", "Right Half"}' ;;
  *) echo "usage: tile.sh left|right" >&2; exit 1 ;;
esac

osascript <<EOF
tell application "System Events"
  set frontProc to first application process whose frontmost is true
  tell frontProc
    set mr to menu "Move & Resize" of menu item "Move & Resize" of menu "Window" of menu bar 1
    repeat with n in $names
      if exists menu item n of mr then
        click menu item n of mr
        return
      end if
    end repeat
  end tell
end tell
EOF
