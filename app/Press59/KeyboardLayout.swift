import Carbon
import Foundation

/// What the keys type in the active keyboard layout, so the cheat sheet matches your keyboard
/// (Colemak, AZERTY, Dvorak…) and shortcuts work in non-Latin layouts too.
enum KeyboardLayout {
    /// The letter keys of each row by virtual key code, left to right, including the punctuation
    /// keys that some layouts put letters on (AZERTY's M, Dvorak's S and Z).
    static let letterRowKeyCodes: [[UInt16]] = [
        [12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30],
        [0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39],
        [6, 7, 8, 9, 11, 45, 46, 43, 47, 44],
    ]

    /// The letters on each row, given what each key types. Keys that don't type a shortcut letter
    /// are left out, and a letter only shows once.
    static func letterRows(typedBy character: (UInt16) -> String?) -> [String] {
        var seen = Set<String>()
        return letterRowKeyCodes.map { row in
            row.compactMap { keyCode in
                guard let typed = character(keyCode)?.lowercased(),
                      KeySuggestions.availableKeys.contains(typed),
                      seen.insert(typed).inserted else { return nil }
                return typed
            }
            .joined()
        }
    }

    /// The letter rows of the active layout, or of your Latin layout when the active one isn't
    /// (Russian, Greek…), where shortcuts use the Latin letters.
    static func currentLetterRows() -> [String] {
        let rows = letterRows { character(for: $0, in: TISCopyCurrentKeyboardLayoutInputSource()) }
        if rows.joined().count >= 20 { return rows }
        return letterRows { character(for: $0, in: TISCopyCurrentASCIICapableKeyboardLayoutInputSource()) }
    }

    /// The letter or number a key types in your Latin layout, the one macOS uses for ⌘ shortcuts.
    static func latinCharacter(for keyCode: UInt16) -> String? {
        character(for: keyCode, in: TISCopyCurrentASCIICapableKeyboardLayoutInputSource())?.lowercased()
    }

    /// What `keyCode` types with no modifiers in `source`.
    private static func character(for keyCode: UInt16, in source: Unmanaged<TISInputSource>?) -> String? {
        guard let source = source?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        return data.withUnsafeBytes { bytes -> String? in
            guard let layout = bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return nil }
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()),
                                        OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState,
                                        chars.count, &length, &chars)
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length)
        }
    }
}
