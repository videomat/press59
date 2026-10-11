import AppKit

struct AppBinding: Identifiable, Codable, Hashable {
    var id = UUID()
    /// A single lowercase character, e.g. "c".
    var key: String
    var appURL: URL

    var appName: String {
        FileManager.default.displayName(atPath: appURL.path)
            .replacingOccurrences(of: ".app", with: "")
    }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: appURL.path)
    }
}

final class BindingStore: ObservableObject {
    static let availableKeys: [String] =
        "abcdefghijklmnopqrstuvwxyz0123456789".map(String.init)

    private static let bindingsKey = "bindings"
    private static let hidesFrontmostAppKey = "hidesFrontmostApp"
    private static let quickTapTogglesCapsLockKey = "quickTapTogglesCapsLock"

    @Published var bindings: [AppBinding] {
        didSet { saveBindings() }
    }

    @Published var hidesFrontmostApp: Bool {
        didSet { UserDefaults.standard.set(hidesFrontmostApp, forKey: Self.hidesFrontmostAppKey) }
    }

    @Published var quickTapTogglesCapsLock: Bool {
        didSet { UserDefaults.standard.set(quickTapTogglesCapsLock, forKey: Self.quickTapTogglesCapsLockKey) }
    }

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.bindingsKey),
           let saved = try? JSONDecoder().decode([AppBinding].self, from: data) {
            bindings = saved
        } else {
            bindings = Self.starterBindings()
        }
        hidesFrontmostApp = defaults.object(forKey: Self.hidesFrontmostAppKey) as? Bool ?? true
        quickTapTogglesCapsLock = defaults.object(forKey: Self.quickTapTogglesCapsLockKey) as? Bool ?? true
    }

    func binding(for key: String) -> AppBinding? {
        bindings.first { $0.key == key }
    }

    func freeKeys(including key: String? = nil) -> [String] {
        let taken = Set(bindings.map(\.key))
        return Self.availableKeys.filter { !taken.contains($0) || $0 == key }
    }

    func add(appURL: URL) {
        let name = FileManager.default.displayName(atPath: appURL.path).lowercased()
        let free = freeKeys()
        guard let key = name.map(String.init).first(where: free.contains) ?? free.first else { return }
        bindings.append(AppBinding(key: key, appURL: appURL))
    }

    func remove(_ binding: AppBinding) {
        bindings.removeAll { $0.id == binding.id }
    }

    private func saveBindings() {
        guard let data = try? JSONEncoder().encode(bindings) else { return }
        UserDefaults.standard.set(data, forKey: Self.bindingsKey)
    }

    /// Seeds a couple of common shortcuts on first launch when the apps are installed.
    private static func starterBindings() -> [AppBinding] {
        let candidates = [
            ("c", "com.google.Chrome"),
            ("s", "com.tinyspeck.slackmacgap"),
            ("f", "com.apple.finder"),
        ]
        return candidates.compactMap { key, bundleID in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
                .map { AppBinding(key: key, appURL: $0) }
        }
    }
}
