import Foundation

/// Picks shortcut keys from app names.
enum KeySuggestions {
    static let availableKeys: [String] = "abcdefghijklmnopqrstuvwxyz0123456789".map(String.init)

    /// Vendor names dropped from the front of an app's name, so Google Chrome gets C, not G.
    private static let vendors: Set<String> = ["adobe", "apple", "google", "microsoft"]

    /// The first letter of `name` that isn't taken, starting after any vendor name, or nil.
    static func key(for name: String, taken: Set<String>) -> String? {
        var words = name.lowercased().split(separator: " ")
        if words.count > 1, let first = words.first, vendors.contains(String(first)) {
            words.removeFirst()
        }
        return words.joined(separator: " ").map(String.init)
            .first { availableKeys.contains($0) && !taken.contains($0) }
    }

    /// A key for each name in turn, so earlier names get first pick. Nil where no letter is free.
    static func keys(for names: [String], taken: Set<String>) -> [String?] {
        var taken = taken
        return names.map { name in
            let key = key(for: name, taken: taken)
            if let key { taken.insert(key) }
            return key
        }
    }
}
