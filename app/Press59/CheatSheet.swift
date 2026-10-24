import AppKit
import SwiftUI

/// Shows your shortcuts on a keyboard while Caps Lock is held on its own.
///
/// The panel floats above everything, on every Space and over full-screen apps, and never takes
/// focus or clicks, so the app you're in keeps typing as soon as Caps Lock is released.
final class CheatSheetController {
    private let store: BindingStore
    private var panel: NSPanel?
    private var isShown = false

    init(store: BindingStore) {
        self.store = store
    }

    func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        isShown = true

        // Rebuilt each time, so it always shows the current shortcuts.
        let content = NSHostingView(rootView: CheatSheetView(bindings: store.bindings))
        panel.contentView = content
        panel.setContentSize(content.fittingSize)
        center(panel)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard isShown, let panel else { return }
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

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
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

    /// Centers the panel on the screen with the mouse pointer, where you're most likely looking.
    private func center(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
    }
}

struct CheatSheetView: View {
    let bindings: [AppBinding]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("⇪ Caps Lock + key")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.55))
            ShortcutKeyboard(bindings: bindings)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.12)))
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
        let rows = Self.rows.filter { row in row.keys.first != "1" || row.keys.contains { byKey[String($0)] != nil } }
        let firstIndent = rows.first?.indent ?? 0

        VStack(alignment: .leading, spacing: Self.spacing) {
            ForEach(rows, id: \.keys) { row in
                HStack(spacing: Self.spacing) {
                    ForEach(row.keys.map(String.init), id: \.self) { key in
                        let shortcutKey = ShortcutKey(key: key, binding: byKey[key], isNew: newKeys.contains(key),
                                                      isDimmed: dimmedKeys.contains(key))
                        if tappableKeys.contains(key) {
                            Button { onTap(key) } label: { shortcutKey }
                                .buttonStyle(.plain)
                        } else {
                            shortcutKey
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
