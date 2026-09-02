import Foundation
import IOKit
import IOKit.hid

let mosBundleID = "com.caldis.Mos"
let launchDelay = 0.4
let quitGrace = 20.0 // grace before quitting so a briefly sleeping BT mouse doesn't flap MOS

setvbuf(stdout, nil, _IONBF, 0)

let logFmt: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f
}()

func log(_ msg: String) {
    print("[\(logFmt.string(from: Date()))] \(msg)")
}

var presentMice = Set<UInt64>()
var lastApplied: Bool?
var pendingWork: DispatchWorkItem?

func cfProp(_ service: io_service_t, _ key: String) -> AnyObject? {
    IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
}

// A device is a mouse if ANY HID collection is Generic Desktop (0x01) / Mouse (0x02).
// Composite BT devices (e.g. Keychron M4) report a keyboard PrimaryUsage but carry a Mouse collection in DeviceUsagePairs.
func hasMouseCollection(_ service: io_service_t) -> Bool {
    if let pairs = cfProp(service, "DeviceUsagePairs") as? [NSDictionary] {
        for pair in pairs {
            if (pair["DeviceUsagePage"] as? NSNumber)?.intValue == 0x01,
               (pair["DeviceUsage"] as? NSNumber)?.intValue == 0x02 { return true }
        }
    }
    return (cfProp(service, "PrimaryUsagePage") as? NSNumber)?.intValue == 0x01
        && (cfProp(service, "PrimaryUsage") as? NSNumber)?.intValue == 0x02
}

// External mouse = has a Mouse collection, not built-in, on a real USB/Bluetooth transport.
// The transport check rejects virtual pointers (e.g. Karabiner's VirtualHIDPointing) that mimic a mouse.
func isExternalMouse(_ service: io_service_t) -> Bool {
    guard hasMouseCollection(service) else { return false }
    if let builtIn = (cfProp(service, "Built-In") as? NSNumber)?.boolValue, builtIn { return false }
    guard let transport = (cfProp(service, "Transport") as? String)?.lowercased() else { return false }
    return transport.hasPrefix("usb") || transport.contains("bluetooth") || transport.hasPrefix("bt")
}

func productName(_ service: io_service_t) -> String {
    (cfProp(service, "Product") as? String) ?? "unknown mouse"
}

func shell(_ path: String, _ args: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    do { try p.run() } catch { log("failed: \(path) \(args) — \(error)") }
}

func scheduleApply() {
    pendingWork?.cancel()
    let delay = presentMice.isEmpty ? quitGrace : launchDelay
    let work = DispatchWorkItem { applyState() }
    pendingWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
}

func applyState() {
    let present = !presentMice.isEmpty
    if present == lastApplied { return }
    lastApplied = present
    if present {
        log("external mouse present -> launching MOS")
        shell("/usr/bin/open", ["-g", "-b", mosBundleID])
    } else {
        log("no external mouse -> quitting MOS")
        shell("/usr/bin/pkill", ["-x", "Mos"])
    }
}

func handleFirstMatch(_ iterator: io_iterator_t) {
    var changed = false
    while case let service = IOIteratorNext(iterator), service != 0 {
        defer { IOObjectRelease(service) }
        var entryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(service, &entryID)
        if isExternalMouse(service), presentMice.insert(entryID).inserted {
            changed = true
            log("mouse connected: \(productName(service))")
        }
    }
    if changed { scheduleApply() }
}

func handleTerminate(_ iterator: io_iterator_t) {
    var changed = false
    while case let service = IOIteratorNext(iterator), service != 0 {
        defer { IOObjectRelease(service) }
        var entryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(service, &entryID)
        if presentMice.remove(entryID) != nil {
            changed = true
            log("mouse disconnected")
        }
    }
    if changed { scheduleApply() }
}

func listMice() {
    var iter: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDDevice"), &iter) == KERN_SUCCESS else {
        print("enumeration failed"); return
    }
    defer { IOObjectRelease(iter) }
    print("HID devices with a Mouse collection:")
    var any = false
    while case let s = IOIteratorNext(iter), s != 0 {
        defer { IOObjectRelease(s) }
        guard hasMouseCollection(s) else { continue }
        any = true
        let transport = (cfProp(s, "Transport") as? String) ?? "none"
        let builtIn = (cfProp(s, "Built-In") as? NSNumber)?.boolValue ?? false
        let tag = isExternalMouse(s) ? "MOUSE " : "ignore"
        print("  [\(tag)] \(productName(s))  (transport=\(transport), builtIn=\(builtIn))")
    }
    if !any { print("  (none)") }
}

if CommandLine.arguments.dropFirst().first == "list" {
    listMice()
    exit(0)
}

guard let notifyPort = IONotificationPortCreate(kIOMainPortDefault) else {
    log("failed to create IONotificationPort"); exit(1)
}
let source = IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue()
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)

let onMatch: IOServiceMatchingCallback = { _, iter in handleFirstMatch(iter) }
let onTerm: IOServiceMatchingCallback = { _, iter in handleTerminate(iter) }

var matchIter: io_iterator_t = 0
IOServiceAddMatchingNotification(notifyPort, kIOFirstMatchNotification, IOServiceMatching("IOHIDDevice"), onMatch, nil, &matchIter)
handleFirstMatch(matchIter)

var termIter: io_iterator_t = 0
IOServiceAddMatchingNotification(notifyPort, kIOTerminatedNotification, IOServiceMatching("IOHIDDevice"), onTerm, nil, &termIter)
handleTerminate(termIter)

log("mos-mouse-watcher started; \(presentMice.count) external mouse(mice) present")
scheduleApply()

CFRunLoopRun()
