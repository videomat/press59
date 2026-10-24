import Foundation

/// A key event as the Hyper key logic sees it.
struct HyperKeyEvent {
    var isDown: Bool
    var isRepeat = false
    /// Whether this is the Hyper key itself (Caps Lock, which sends F18).
    var isHyperKey = false
    /// The typed character, lowercased, if any.
    var character: String?
    /// The virtual key code, for keys without a character such as the arrows.
    var keyCode: Int64?
}

/// What to do with a key event.
enum HyperKeyAction: Equatable {
    /// Let the event through unchanged.
    case passThrough
    /// Let it through with ⌃⌥⇧⌘ added.
    case addHyperModifiers
    /// Drop it.
    case swallow
    /// Drop it and toggle Caps Lock (a quick tap of the Hyper key).
    case toggleCapsLock
    /// Drop it and open Settings.
    case openSettings
    /// Drop it and open (or hide) the app.
    case openApp(URL)
    /// Drop it and move the front window.
    case moveWindow(WindowPosition)

    /// Whether the event should still reach other apps.
    var passesEvent: Bool {
        self == .passThrough || self == .addHyperModifiers
    }
}

/// The Hyper key's decision-making, separate from the event tap so it can be tested:
/// - Hyper + an assigned key opens that app; Hyper + `settingsKey` opens Settings.
/// - Hyper + an arrow key moves the front window (optional).
/// - Hyper + any other key gets ⌃⌥⇧⌘.
/// - Pressing and releasing Hyper with no other key in between is a quick tap.
/// - Holding Hyper on its own for `cheatSheetDelay` shows the cheat sheet instead.
struct HyperKeyState {
    static let settingsKey = ","
    static let cheatSheetDelay: TimeInterval = 0.5

    private(set) var isHyperDown = false
    /// Whether another key was pressed while Hyper was held, so releasing it isn't a quick tap.
    private var wasHyperUsed = false

    mutating func handle(
        _ event: HyperKeyEvent,
        quickTapTogglesCapsLock: Bool,
        movesWindows: Bool,
        appForKey: (String) -> URL?
    ) -> HyperKeyAction {
        if event.isHyperKey {
            if event.isDown {
                if !event.isRepeat {
                    isHyperDown = true
                    wasHyperUsed = false
                }
                return .swallow
            }
            let wasTap = isHyperDown && !wasHyperUsed
            isHyperDown = false
            return wasTap && quickTapTogglesCapsLock ? .toggleCapsLock : .swallow
        }

        guard isHyperDown else { return .passThrough }
        wasHyperUsed = true

        // Act on the first key-down only; repeats and key-ups of a shortcut are dropped too.
        let acts = event.isDown && !event.isRepeat
        if movesWindows, let keyCode = event.keyCode, let position = WindowPosition(keyCode: keyCode) {
            return acts ? .moveWindow(position) : .swallow
        }
        if event.character == Self.settingsKey {
            return acts ? .openSettings : .swallow
        }
        if let character = event.character, let appURL = appForKey(character) {
            return acts ? .openApp(appURL) : .swallow
        }
        return .addHyperModifiers
    }

    /// Called when Hyper has been held for `cheatSheetDelay`. Returns whether to show the cheat sheet:
    /// only while Hyper is still down on its own. Releasing it afterwards is then not a quick tap.
    mutating func holdElapsed() -> Bool {
        guard isHyperDown, !wasHyperUsed else { return false }
        wasHyperUsed = true
        return true
    }

    mutating func reset() {
        isHyperDown = false
        wasHyperUsed = false
    }
}
