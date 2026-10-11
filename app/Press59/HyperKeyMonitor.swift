import AppKit
import ApplicationServices
import IOKit.hidsystem

/// Turns Caps Lock into a Hyper key.
///
/// Caps Lock is remapped to F18 at the HID level with `hidutil`, so it no longer toggles
/// capitals. A keyboard event tap then treats F18 as a held modifier:
/// - Hyper + a bound key opens (or hides) that app.
/// - Hyper + any other key is sent on as ⌃⌥⇧⌘ + key, so other apps can use it as a shortcut.
/// - A quick tap of Caps Lock on its own still toggles Caps Lock (optional).
final class HyperKeyMonitor: ObservableObject {
    @Published private(set) var isTrusted = AXIsProcessTrusted()
    @Published private(set) var isRunning = false

    private static let capsLockUsage = "0x700000039"
    private static let f18Usage = "0x70000006D"
    private static let f18KeyCode: Int64 = 0x4F
    private static let hyperFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]

    /// Hyper + this key opens Settings, so they're reachable when macOS hides the menu bar icon.
    static let settingsKey = ","

    /// Called when Hyper + `settingsKey` is pressed.
    var onOpenSettings: (() -> Void)?

    private let store: BindingStore
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var trustTimer: Timer?
    private var isHyperDown = false
    /// Whether another key was pressed while Hyper was held, so releasing it isn't a quick tap.
    private var wasHyperUsed = false

    init(store: BindingStore) {
        self.store = store
    }

    func start() {
        guard !isRunning else { return }
        guard requestTrust() else {
            waitForTrust()
            return
        }
        guard installTap() else { return }
        setCapsLockRemapped(true)
        isRunning = true
    }

    func stop() {
        trustTimer?.invalidate()
        trustTimer = nil
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        isHyperDown = false
        if isRunning {
            setCapsLockRemapped(false)
        }
        isRunning = false
    }

    // MARK: - Accessibility

    @discardableResult
    private func requestTrust() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
        return isTrusted
    }

    private func waitForTrust() {
        trustTimer?.invalidate()
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self, AXIsProcessTrusted() else { return }
            timer.invalidate()
            self.trustTimer = nil
            self.isTrusted = true
            self.start()
        }
    }

    // MARK: - Caps Lock remapping

    private func setCapsLockRemapped(_ remapped: Bool) {
        let mapping = remapped
            ? #"{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":\#(Self.capsLockUsage),"HIDKeyboardModifierMappingDst":\#(Self.f18Usage)}]}"#
            : #"{"UserKeyMapping":[]}"#
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property", "--set", mapping]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    /// Flips the system Caps Lock state (and its light), since the physical key now sends F18.
    private func toggleCapsLock() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        var connect: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect) == KERN_SUCCESS else { return }
        defer { IOServiceClose(connect) }
        var isOn = false
        IOHIDGetModifierLockState(connect, Int32(kIOHIDCapsLockState), &isOn)
        IOHIDSetModifierLockState(connect, Int32(kIOHIDCapsLockState), !isOn)
    }

    // MARK: - Event tap

    private func installTap() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<HyperKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handle(type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        runLoopSource = source
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        case .keyDown, .keyUp:
            break
        default:
            return Unmanaged.passUnretained(event)
        }

        let isKeyDown = type == .keyDown
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if event.getIntegerValueField(.keyboardEventKeycode) == Self.f18KeyCode {
            if isKeyDown && !isRepeat {
                isHyperDown = true
                wasHyperUsed = false
            } else if !isKeyDown {
                isHyperDown = false
                if !wasHyperUsed && store.quickTapTogglesCapsLock {
                    toggleCapsLock()
                }
            }
            return nil
        }
        guard isHyperDown else { return Unmanaged.passUnretained(event) }
        wasHyperUsed = true

        let key = character(of: event)
        if key == Self.settingsKey {
            if isKeyDown && !isRepeat {
                onOpenSettings?()
            }
            return nil
        }
        if let key, let binding = store.binding(for: key) {
            if isKeyDown && !isRepeat {
                toggle(binding.appURL)
            }
            return nil
        }

        event.flags.formUnion(Self.hyperFlags)
        return Unmanaged.passUnretained(event)
    }

    private func character(of event: CGEvent) -> String? {
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: chars.count, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length).lowercased()
    }

    // MARK: - Apps

    private func toggle(_ appURL: URL) {
        let bundleID = Bundle(url: appURL)?.bundleIdentifier
        if store.hidesFrontmostApp,
           let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.bundleIdentifier == bundleID {
            frontmost.hide()
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
    }
}
