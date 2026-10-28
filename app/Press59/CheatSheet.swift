import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Shows your shortcuts on a keyboard while Caps Lock is held on its own.
///
/// The panel floats above everything, on every Space and over full-screen apps, without taking
/// focus, so the app you're in keeps typing as soon as Caps Lock is released.
///
/// Clicking a key pins it open to add or change shortcuts: each key offers the app you were in,
/// your other open apps, or any app, and once it's pinned, typing a key does the same. Escape,
/// Done or a click elsewhere closes it and goes back to that app.
final class CheatSheetController {
    private let store: BindingStore
    private var panel: OverlayPanel?
    private var isShown = false
    /// Whether a click pinned the sheet open to add or change shortcuts.
    private var isEditing = false
    /// The app that was in front when editing began: offered first, and brought back after.
    private var previousApp: NSRunningApplication?
    /// Where each key is in the panel (top-left origin), for opening its menu below it.
    private var keyFrames: [String: CGRect] = [:]
    private var eventMonitors: [Any] = []

    init(store: BindingStore) {
        self.store = store
    }

    func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        isShown = true
        refresh()
        guard !isEditing else { return }
        center(panel)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        // Pinned for editing: it stays up after Caps Lock is released.
        guard isShown, !isEditing, let panel else { return }
        isShown = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // Shown again while fading out: keep it up.
            guard self?.isShown == false else { return }
            panel.orderOut(nil)
        })
    }

    private func makePanel() -> OverlayPanel {
        let panel = NSPanel.overlay()
        // Unlike the keystroke overlay, the keys can be clicked.
        panel.ignoresMouseEvents = false
        return panel
    }

    /// Rebuilt each time, so it always shows the current shortcuts. Keeps the panel's center, since
    /// the size changes when editing adds the number row.
    private func refresh() {
        guard let panel else { return }
        let view = CheatSheetView(
            bindings: store.bindings,
            movesWindows: store.movesWindows,
            isEditing: isEditing,
            onTapKey: { [weak self] key in self?.tap(key) },
            onKeyFrames: { [weak self] frames in self?.keyFrames = frames },
            onDone: { [weak self] in self?.endEditing() }
        )
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let content = NSHostingView(rootView: view)
        panel.contentView = content
        panel.setContentSize(content.fittingSize)
        if panel.isVisible {
            panel.setFrameOrigin(NSPoint(x: center.x - panel.frame.width / 2, y: center.y - panel.frame.height / 2))
        }
    }

    /// Centers the panel on the screen with the mouse pointer, where you're most likely looking.
    private func center(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
    }

    // MARK: - Editing

    private func tap(_ key: String) {
        if !isEditing { beginEditing() }
        showMenu(for: key)
    }

    private func beginEditing() {
        guard let panel else { return }
        // The sheet never took focus, so the app in front is still the one you were in.
        let frontmost = NSWorkspace.shared.frontmostApplication
        previousApp = frontmost?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : frontmost
        isEditing = true
        // Below Choose App's open panel, and able to take the keyboard for typing a key.
        panel.level = .floating
        panel.acceptsKey = true
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
        refresh()
        watchWhileEditing()
    }

    private func endEditing() {
        guard isEditing, let panel else { return }
        eventMonitors.forEach(NSEvent.removeMonitor)
        eventMonitors = []
        isEditing = false
        panel.acceptsKey = false
        panel.level = .popUpMenu
        hide()
        previousApp?.activate()
        previousApp = nil
    }

    private func watchWhileEditing() {
        // A click in another app, or on the desktop or menu bar.
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            self?.endEditing()
        }) {
            eventMonitors.append(monitor)
        }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard let self, event.window === panel else { return event }
            if event.keyCode == 53 || event.keyCode == 36 { // Escape, Return
                endEditing()
                return nil
            }
            let modifiers = event.modifierFlags.intersection([.command, .control, .option])
            if modifiers.isEmpty, let key = event.charactersIgnoringModifiers?.lowercased(),
               KeySuggestions.availableKeys.contains(key) {
                showMenu(for: key)
                return nil
            }
            return event
        }) {
            eventMonitors.append(monitor)
        }
    }

    /// The key's app (if any) and what to give the key instead: the app you were in, your other
    /// open apps, or any app.
    private func showMenu(for key: String) {
        guard let panel else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false
        let label = "⇪ \(key.uppercased())"

        if let binding = store.binding(for: key) {
            let current = NSMenuItem(title: "\(label)  \(binding.appName)", action: nil, keyEquivalent: "")
            current.image = AppIconCache.icon(for: binding.appURL, pointSize: 16)
            current.isEnabled = false
            menu.addItem(current)
            menu.addItem(ClosureMenuItem("Remove Shortcut") { [weak self] in
                self?.store.remove(binding)
                self?.refresh()
            })
            menu.addItem(.separator())
            menu.addItem(Self.header("Change to"))
        } else {
            menu.addItem(Self.header("Open with \(label)"))
        }

        let current = store.binding(for: key)?.appURL.standardizedFileURL
        let apps = Self.openApps(first: previousApp).filter { $0.standardizedFileURL != current }
        for (index, appURL) in apps.enumerated() {
            let item = ClosureMenuItem(AppBinding.name(of: appURL)) { [weak self] in self?.assign(appURL, to: key) }
            item.image = AppIconCache.icon(for: appURL, pointSize: 16)
            menu.addItem(item)
            // The app you were in comes first, on its own.
            if index == 0, previousApp != nil, apps.count > 1 {
                menu.addItem(.separator())
            }
        }
        if !apps.isEmpty {
            menu.addItem(.separator())
        }
        menu.addItem(ClosureMenuItem("Choose App…") { [weak self] in self?.chooseApp(for: key) })

        // Below the key, or the middle of the sheet if its frame isn't known yet.
        let frame = keyFrames[key] ?? CGRect(x: panel.frame.width / 2, y: panel.frame.height / 2, width: 0, height: 0)
        let point = NSPoint(x: panel.frame.minX + frame.minX, y: panel.frame.maxY - frame.maxY - 4)
        menu.popUp(positioning: nil, at: point, in: nil)
    }

    private func assign(_ appURL: URL, to key: String) {
        store.assign(appURL: appURL, to: key)
        refresh()
    }

    private func chooseApp(for key: String) {
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        openPanel.allowedContentTypes = [.application]
        openPanel.prompt = "Choose"
        guard openPanel.runModal() == .OK, let appURL = openPanel.url else { return }
        assign(appURL, to: key)
    }

    private static func header(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    /// Open apps with a Dock icon, `first` leading and the rest by name, without Press59.
    private static func openApps(first: NSRunningApplication?) -> [URL] {
        let others = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0 != first && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "").localizedStandardCompare($1.localizedName ?? "") == .orderedAscending }
        var seen = Set<URL>()
        return ([first].compactMap { $0 } + others).compactMap(\.bundleURL)
            .filter { seen.insert($0.standardizedFileURL).inserted }
    }
}

/// A floating panel that can be allowed to take the keyboard, as the cheat sheet does while editing.
final class OverlayPanel: NSPanel {
    var acceptsKey = false
    override var canBecomeKey: Bool { acceptsKey }
}

extension NSPanel {
    /// A panel for the cheat sheet and the keystroke overlay: above everything, on every Space and
    /// over full-screen apps, and never taking focus or clicks.
    static func overlay() -> OverlayPanel {
        let panel = OverlayPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        return panel
    }
}

/// A menu item that runs a closure.
private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, action handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    @objc private func run() {
        handler()
    }
}

struct CheatSheetView: View {
    let bindings: [AppBinding]
    var movesWindows = false
    var isEditing = false
    var onTapKey: (String) -> Void = { _ in }
    var onKeyFrames: ([String: CGRect]) -> Void = { _ in }
    var onDone: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(isEditing ? "Click a key, or type it, to choose its app" : "⇪ Caps Lock + key")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.55))
                Spacer()
                if isEditing {
                    Button("Done", action: onDone)
                        .controlSize(.small)
                }
            }
            ShortcutKeyboard(
                bindings: bindings,
                tappableKeys: Set(KeySuggestions.availableKeys),
                showsNumberRow: isEditing,
                onTap: onTapKey
            )
            .onPreferenceChange(KeyFramesKey.self, perform: onKeyFrames)
            if !isEditing {
                HStack(spacing: 24) {
                    if movesWindows {
                        Text("⇪ ← → ↑ ↓  Move the window")
                        Text("⇪ ↩  Fill the screen")
                    }
                    Spacer()
                    Text("Click a key to change it")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.55))
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .coordinateSpace(name: CheatSheetView.space)
    }

    static let space = "cheatSheet"
}

/// Where each key of a `ShortcutKeyboard` is, for the cheat sheet's key menus.
struct KeyFramesKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// A keyboard with each app on its key. Used by the cheat sheet and the Dock suggestions.
struct ShortcutKeyboard: View {
    let bindings: [AppBinding]
    /// Keys to tint as new, e.g. suggested shortcuts not added yet.
    var newKeys: Set<String> = []
    /// Keys whose app is shown faded, e.g. suggestions left out.
    var dimmedKeys: Set<String> = []
    /// Called when one of `tappableKeys` is clicked.
    var tappableKeys: Set<String> = []
    /// Whether to show the number row even when no number has a shortcut.
    var showsNumberRow = false
    var onTap: (String) -> Void = { _ in }

    /// Keyboard rows, each with how far it's indented on a real keyboard (in key widths).
    private static let rows: [(keys: String, indent: CGFloat)] = [
        ("1234567890", 0),
        ("qwertyuiop", 0.5),
        ("asdfghjkl", 0.75),
        ("zxcvbnm" + HyperKeyState.settingsKey, 1.25),
    ]
    static let keySize: CGFloat = 64
    private static let spacing: CGFloat = 8

    var body: some View {
        let byKey = Dictionary(bindings.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        // The number row only when a number has a shortcut.
        let rows = Self.rows.filter { row in
            row.keys.first != "1" || showsNumberRow || row.keys.contains { byKey[String($0)] != nil }
        }
        let firstIndent = rows.first?.indent ?? 0

        VStack(alignment: .leading, spacing: Self.spacing) {
            ForEach(rows, id: \.keys) { row in
                HStack(spacing: Self.spacing) {
                    ForEach(row.keys.map(String.init), id: \.self) { key in
                        let shortcutKey = ShortcutKey(key: key, binding: byKey[key], isNew: newKeys.contains(key),
                                                      isDimmed: dimmedKeys.contains(key))
                        Group {
                            if tappableKeys.contains(key) {
                                Button { onTap(key) } label: { shortcutKey }
                                    .buttonStyle(.plain)
                            } else {
                                shortcutKey
                            }
                        }
                        .background {
                            GeometryReader { geometry in
                                Color.clear.preference(key: KeyFramesKey.self,
                                                       value: [key: geometry.frame(in: .named(CheatSheetView.space))])
                            }
                        }
                    }
                }
                .padding(.leading, (row.indent - firstIndent) * (Self.keySize + Self.spacing))
            }
        }
    }
}

private struct ShortcutKey: View {
    let key: String
    let binding: AppBinding?
    let isNew: Bool
    var isDimmed = false

    /// Press59's orange, as in the app icon and on press59.win.
    private static let orange = Color(red: 1, green: 0.42, blue: 0.17)

    private var isSettings: Bool { key == HyperKeyState.settingsKey }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isNew ? Self.orange.opacity(0.28) : Color.primary.opacity(binding == nil && !isSettings ? 0.04 : 0.1))
                .overlay {
                    if isNew {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Self.orange, lineWidth: 1.5)
                    }
                }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(isDimmed ? 0.35 : 1)
            if binding != nil || isSettings {
                Text(key.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.55))
                    .padding(5)
            }
        }
        .frame(width: ShortcutKeyboard.keySize, height: ShortcutKeyboard.keySize)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    @ViewBuilder private var content: some View {
        if let binding {
            label(Image(nsImage: binding.largeIcon).resizable().frame(width: 34, height: 34), binding.appName)
        } else if isSettings {
            label(Image(systemName: "gearshape.fill").font(.system(size: 22)).foregroundStyle(Color.primary.opacity(0.55)), "Settings")
        } else {
            Text(key.uppercased())
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(0.25))
        }
    }

    private func label(_ image: some View, _ name: String) -> some View {
        VStack(spacing: 3) {
            image
            Text(name)
                .font(.system(size: 9.5, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .truncationMode(.tail)
                .padding(.horizontal, 4)
        }
        .padding(.top, 8)
    }
}
