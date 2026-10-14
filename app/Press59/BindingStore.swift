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

    /// A small copy of the app's icon for the Settings list. See `AppIconCache`.
    var icon: NSImage {
        AppIconCache.icon(for: appURL)
    }
}

/// App icons hold every size up to 1024 pt @2x (about 16 MB each once decoded), but Settings shows
/// them at 20 pt. Each icon is shrunk once to that size and cached, so the large original is released.
enum AppIconCache {
    static let pointSize: CGFloat = 20
    private static var icons: [URL: NSImage] = [:]

    static func icon(for appURL: URL) -> NSImage {
        if let icon = icons[appURL] { return icon }
        let icon = thumbnail(of: NSWorkspace.shared.icon(forFile: appURL.path))
        icons[appURL] = icon
        return icon
    }

    private static func thumbnail(of source: NSImage) -> NSImage {
        let size = NSSize(width: pointSize, height: pointSize)
        let pixels = Int(pointSize * 2)
        let thumbnail = NSImage(size: size)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return source }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        thumbnail.addRepresentation(rep)
        return thumbnail
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
