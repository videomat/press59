import AppKit

struct AppBinding: Identifiable, Codable, Hashable {
    var id = UUID()
    /// A single lowercase character, e.g. "c".
    var key: String
    var appURL: URL

    var appName: String {
        Self.name(of: appURL)
    }

    static func name(of appURL: URL) -> String {
        FileManager.default.displayName(atPath: appURL.path)
            .replacingOccurrences(of: ".app", with: "")
    }

    /// A small copy of the app's icon for the Settings list. See `AppIconCache`.
    var icon: NSImage {
        AppIconCache.icon(for: appURL)
    }

    /// A larger copy for the cheat sheet.
    var largeIcon: NSImage {
        AppIconCache.icon(for: appURL, pointSize: 36)
    }
}

/// App icons hold every size up to 1024 pt @2x (about 16 MB each once decoded), but Settings shows
/// them at 20 pt and the cheat sheet at 36 pt. Each icon is shrunk once to the size shown and cached,
/// so the large original is released.
enum AppIconCache {
    private struct Key: Hashable {
        var appURL: URL
        var pointSize: CGFloat
    }

    private static var icons: [Key: NSImage] = [:]

    static func icon(for appURL: URL, pointSize: CGFloat = 20) -> NSImage {
        let key = Key(appURL: appURL, pointSize: pointSize)
        if let icon = icons[key] { return icon }
        let icon = thumbnail(of: NSWorkspace.shared.icon(forFile: appURL.path), pointSize: pointSize)
        icons[key] = icon
        return icon
    }

    private static func thumbnail(of source: NSImage, pointSize: CGFloat) -> NSImage {
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
    private static let bindingsKey = "bindings"
    private static let hidesFrontmostAppKey = "hidesFrontmostApp"
    private static let quickTapTogglesCapsLockKey = "quickTapTogglesCapsLock"
    private static let showsCheatSheetKey = "showsCheatSheet"
    private static let movesWindowsKey = "movesWindows"

    @Published var bindings: [AppBinding] {
        didSet { saveBindings() }
    }

    @Published var hidesFrontmostApp: Bool {
        didSet { UserDefaults.standard.set(hidesFrontmostApp, forKey: Self.hidesFrontmostAppKey) }
    }

    @Published var quickTapTogglesCapsLock: Bool {
        didSet { UserDefaults.standard.set(quickTapTogglesCapsLock, forKey: Self.quickTapTogglesCapsLockKey) }
    }

    @Published var showsCheatSheet: Bool {
        didSet { UserDefaults.standard.set(showsCheatSheet, forKey: Self.showsCheatSheetKey) }
    }

    @Published var movesWindows: Bool {
        didSet { UserDefaults.standard.set(movesWindows, forKey: Self.movesWindowsKey) }
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
        showsCheatSheet = defaults.object(forKey: Self.showsCheatSheetKey) as? Bool ?? true
        movesWindows = defaults.object(forKey: Self.movesWindowsKey) as? Bool ?? true
    }

    func binding(for key: String) -> AppBinding? {
        bindings.first { $0.key == key }
    }

    func freeKeys(including key: String? = nil) -> [String] {
        let taken = Set(bindings.map(\.key))
        return KeySuggestions.availableKeys.filter { !taken.contains($0) || $0 == key }
    }

    func add(appURL: URL) {
        let taken = Set(bindings.map(\.key))
        guard let key = KeySuggestions.key(for: AppBinding.name(of: appURL), taken: taken) ?? freeKeys().first else { return }
        bindings.append(AppBinding(key: key, appURL: appURL))
    }

    /// Dock apps without a shortcut yet, each given a free letter from its name.
    var dockAppsToAdd: [AppBinding] {
        let bound = Set(bindings.map(\.appURL.standardizedFileURL))
        return Self.suggestedBindings(for: DockApps.urls().filter { !bound.contains($0.standardizedFileURL) },
                                      taken: Set(bindings.map(\.key)))
    }

    func addDockApps() {
        bindings += dockAppsToAdd
    }

    func remove(_ binding: AppBinding) {
        bindings.removeAll { $0.id == binding.id }
    }

    private func saveBindings() {
        guard let data = try? JSONEncoder().encode(bindings) else { return }
        UserDefaults.standard.set(data, forKey: Self.bindingsKey)
    }

    /// Shortcuts for the apps in the Dock on first launch, so Press59 works right away.
    private static func starterBindings() -> [AppBinding] {
        suggestedBindings(for: DockApps.urls(), taken: [])
    }

    private static func suggestedBindings(for appURLs: [URL], taken: Set<String>) -> [AppBinding] {
        let keys = KeySuggestions.keys(for: appURLs.map(AppBinding.name(of:)), taken: taken)
        return zip(keys, appURLs).compactMap { key, appURL in
            key.map { AppBinding(key: $0, appURL: appURL) }
        }
    }
}

/// The apps kept in the Dock, read from the Dock's preferences.
enum DockApps {
    /// Launchers that are always in the Dock and not worth a shortcut.
    private static let skipped: Set<String> = ["com.apple.apps.launcher", "com.apple.launchpad.launcher"]

    static func urls() -> [URL] {
        guard let tiles = CFPreferencesCopyAppValue("persistent-apps" as CFString, "com.apple.dock" as CFString)
                as? [[String: Any]] else { return [] }
        return tiles.compactMap { tile in
            guard let tileData = tile["tile-data"] as? [String: Any],
                  let fileData = tileData["file-data"] as? [String: Any],
                  let string = fileData["_CFURLString"] as? String,
                  let url = URL(string: string), url.isFileURL,
                  FileManager.default.fileExists(atPath: url.path),
                  !skipped.contains(Bundle(url: url)?.bundleIdentifier ?? "") else { return nil }
            return url
        }
    }
}
