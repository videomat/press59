import Foundation

/// One entry of the system's `UserKeyMapping` property, as set with `hidutil`.
struct KeyMapping: Equatable {
    let source: UInt64
    let destination: UInt64
}

/// Edits the system's key mappings without disturbing ones that other tools (Karabiner, scripts,
/// System Settings › Modifier Keys) have set: Press59 only adds and removes its own Caps Lock → F18.
enum KeyMappings {
    static let capsLock: UInt64 = 0x7_0000_0039
    static let f18: UInt64 = 0x7_0000_006D
    static let capsLockToF18 = KeyMapping(source: capsLock, destination: f18)

    /// Parses the output of `hidutil property --get UserKeyMapping`: an old-style property list
    /// array of dictionaries, or `(null)` when nothing is mapped. Returns nil if it can't be read.
    static func parse(_ output: String) -> [KeyMapping]? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "(null)" { return [] }
        guard let data = trimmed.data(using: .utf8),
              let list = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]]
        else { return nil }

        var mappings: [KeyMapping] = []
        for entry in list {
            guard let source = number(entry["HIDKeyboardModifierMappingSrc"]),
                  let destination = number(entry["HIDKeyboardModifierMappingDst"]) else { return nil }
            mappings.append(KeyMapping(source: source, destination: destination))
        }
        return mappings
    }

    /// The mappings with Caps Lock → F18 added. Any other mapping of Caps Lock is replaced,
    /// since a key can only have one destination; everything else is kept as is.
    static func adding(to mappings: [KeyMapping]) -> [KeyMapping] {
        mappings.filter { $0.source != capsLock } + [capsLockToF18]
    }

    /// The mappings without Press59's Caps Lock → F18; everything else is kept as is.
    static func removing(from mappings: [KeyMapping]) -> [KeyMapping] {
        mappings.filter { $0 != capsLockToF18 }
    }

    /// The JSON `hidutil property --set` expects.
    static func json(_ mappings: [KeyMapping]) -> String {
        let entries = mappings.map {
            #"{"HIDKeyboardModifierMappingSrc":\#($0.source),"HIDKeyboardModifierMappingDst":\#($0.destination)}"#
        }
        return #"{"UserKeyMapping":[\#(entries.joined(separator: ","))]}"#
    }

    private static func number(_ value: Any?) -> UInt64? {
        switch value {
        case let number as NSNumber: return number.uint64Value
        case let string as String: return UInt64(string) ?? UInt64(string.replacingOccurrences(of: "0x", with: ""), radix: 16)
        default: return nil
        }
    }
}
