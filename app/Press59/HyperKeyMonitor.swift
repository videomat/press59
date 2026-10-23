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
/// - Holding Caps Lock on its own shows the cheat sheet of shortcuts (optional).
final class HyperKeyMonitor: ObservableObject {
    @Published private(set) var isTrusted = AXIsProcessTrusted()
    @Published private(set) var isRunning = false

    private static let f18KeyCode: Int64 = 0x4F
    private static let hyperFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
    private static let hidutil = URL(fileURLWithPath: "/usr/bin/hidutil")

    /// Called when Hyper + `HyperKeyState.settingsKey` is pressed, so Settings are reachable
    /// when macOS hides the menu bar icon.
    var onOpenSettings: (() -> Void)?
    /// Called to show or hide the cheat sheet while Hyper is held on its own.
    var onShowCheatSheet: (() -> Void)?
    var onHideCheatSheet: (() -> Void)?

    private let store: BindingStore
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var trustTimer: Timer?
    private var cheatSheetTimer: Timer?
    private var state = HyperKeyState()

    init(store: BindingStore) {
        self.store = store
    }

    func start() {
        guard !isRunning else { return }
        guard requestTrust() else {
            retryStartLater()
            return
        }
        // The tap can fail even when trusted, e.g. for a moment right after Accessibility is
        // granted, so keep trying instead of leaving Caps Lock unmapped until a relaunch.
        guard installTap() else {
            retryStartLater()
            return
        }
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
        state.reset()
        endCheatSheet()
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

    /// Calls `start()` again every second, once the app is trusted.
    private func retryStartLater() {
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

    /// Adds or removes only Press59's Caps Lock → F18, keeping mappings set by other tools.
    private func setCapsLockRemapped(_ remapped: Bool) {
        guard let current = KeyMappings.parse(runHidutil(["property", "--get", "UserKeyMapping"])) else {
            // The current mappings can't be read, so they can't be preserved. Remapping still has to
            // work, and removing must not leave Caps Lock stuck as F18, so fall back to Press59's own.
            runHidutil(["property", "--set", KeyMappings.json(remapped ? [KeyMappings.capsLockToF18] : [])])
            return
        }
        let updated = remapped ? KeyMappings.adding(to: current) : KeyMappings.removing(from: current)
        guard updated != current else { return }
        runHidutil(["property", "--set", KeyMappings.json(updated)])
    }

    @discardableResult
    private func runHidutil(_ arguments: [String]) -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = Self.hidutil
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return ""
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
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

        let keyEvent = HyperKeyEvent(
            isDown: type == .keyDown,
            isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
            isHyperKey: event.getIntegerValueField(.keyboardEventKeycode) == Self.f18KeyCode,
            character: character(of: event)
        )
        let action = state.handle(
            keyEvent,
            quickTapTogglesCapsLock: store.quickTapTogglesCapsLock,
            appForKey: { [store] in store.binding(for: $0)?.appURL }
        )
        updateCheatSheet(for: keyEvent)

        switch action {
        case .passThrough, .swallow:
            break
        case .addHyperModifiers:
            event.flags.formUnion(Self.hyperFlags)
        case .toggleCapsLock:
            toggleCapsLock()
        case .openSettings:
            onOpenSettings?()
        case .openApp(let appURL):
            toggle(appURL)
        }
        return action.passesEvent ? Unmanaged.passUnretained(event) : nil
    }

    // MARK: - Cheat sheet

    private func updateCheatSheet(for event: HyperKeyEvent) {
        if event.isHyperKey && event.isDown {
            if !event.isRepeat && store.showsCheatSheet { scheduleCheatSheet() }
            return
        }
        // Letting go of Hyper or pressing any other key ends the hold.
        endCheatSheet()
    }

    private func scheduleCheatSheet() {
        cheatSheetTimer?.invalidate()
        cheatSheetTimer = Timer.scheduledTimer(withTimeInterval: HyperKeyState.cheatSheetDelay, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.cheatSheetTimer = nil
            if self.state.holdElapsed() {
                self.onShowCheatSheet?()
            }
        }
    }

    private func endCheatSheet() {
        cheatSheetTimer?.invalidate()
        cheatSheetTimer = nil
        onHideCheatSheet?()
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
