# mos-mouse-watcher

macOS LaunchAgent that runs [MOS](https://github.com/Caldis/Mos) only while an external mouse is connected, and quits it when the last one disconnects — so trackpad scrolling stays natural and MOS smooths only the real mouse.

## Files
- `main.swift` — Swift/IOKit HID watcher
- `install.sh` — build binary, write the LaunchAgent, load and start it (idempotent)
- `uninstall.sh` — remove watcher, LaunchAgent, binary (MOS itself untouched)

## Install
```sh
./install.sh
```
Requires the Xcode command line tools (`swiftc`). Binary and a copy of the source land in `~/Library/Application Support/mos-mouse-watcher/`; the LaunchAgent is generated at `~/Library/LaunchAgents/com.elrocie.mos-mouse-watcher.plist`; log at `~/Library/Logs/mos-mouse-watcher.log`.

## Mouse detection
A device is treated as an external mouse when it has a Generic Desktop / Mouse HID collection (page 1, usage 2) in its `DeviceUsagePairs`, is not Built-In, and rides a real USB/Bluetooth transport.

- Matching `DeviceUsagePairs` rather than only `PrimaryUsage` is required for composite Bluetooth mice (e.g. Keychron M4) that report a keyboard as their primary usage but carry the mouse collection as a secondary pair.
- The transport check rejects Karabiner-Elements' virtual `VirtualHIDPointing` device (usage 2 but no transport); Built-In rejects the internal trackpad.

MOS is quit `quitGrace` seconds (20 by default) after the last mouse leaves, so a Bluetooth mouse that briefly sleeps doesn't make MOS flap on and off.

## Debug
```sh
"$HOME/Library/Application Support/mos-mouse-watcher/mos-mouse-watcher" list
```
Prints every HID device with a mouse collection and whether the watcher counts it as an external mouse.
