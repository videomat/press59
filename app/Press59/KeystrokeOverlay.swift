import AppKit
import SwiftUI

/// A shortcut as the keystroke overlay shows it.
enum Keystroke {
    /// Hyper + `key` opened `appURL`, or hid it.
    case app(key: String, appURL: URL, hid: Bool)
    /// Hyper + an arrow or Return moved the front window to `position`.
    case window(WindowKey, WindowPosition)
    /// Hyper + `key` was sent on as ⌃⌥⇧⌘ + key.
    case hyper(key: String)
    case settings

    /// Hyper + a key without a shortcut, or nil for keys not worth showing (e.g. a lone modifier).
    static func hyper(character: String?, keyCode: Int64?) -> Keystroke? {
        switch keyCode {
        case 49: return .hyper(key: "Space")
        case 48: return .hyper(key: "⇥")
        case 51: return .hyper(key: "⌫")
        case 53: return .hyper(key: "esc")
        default: break
        }
        guard let character, let scalar = character.unicodeScalars.first,
              !CharacterSet.controlCharacters.contains(scalar) else { return nil }
        return .hyper(key: character.uppercased())
    }
}

/// Shows each Caps Lock shortcut at the bottom of the screen as it's pressed, e.g.
/// "⇪ + C → Chrome", so screen recordings, streams and demos show how you got there.
///
/// Like the cheat sheet, the panel floats above everything and never takes focus or clicks.
final class KeystrokeOverlayController {
    /// How long a shortcut stays on screen after it's pressed.
    private static let shownFor: TimeInterval = 1.4

    private var panel: NSPanel?
    /// Counts shortcuts shown, so a fade-out started for an earlier one doesn't hide a newer one.
    private var generation = 0

    func show(_ keystroke: Keystroke) {
        let panel = self.panel ?? NSPanel.overlay()
        self.panel = panel
        generation += 1
        let shown = generation

        let content = NSHostingView(rootView: KeystrokeView(keystroke: keystroke))
        panel.contentView = content
        panel.setContentSize(content.fittingSize)
        place(panel)

        if !panel.isVisible { panel.alphaValue = 0 }
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.shownFor) { [weak self] in
            guard self?.generation == shown else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                panel.animator().alphaValue = 0
            }, completionHandler: {
                guard self?.generation == shown else { return }
                panel.orderOut(nil)
            })
        }
    }

    /// Near the bottom of the screen with the mouse pointer, centered, where captions usually go.
    private func place(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.minY + 56))
    }
}

struct KeystrokeView: View {
    let keystroke: Keystroke

    /// Press59's orange, as in the app icon and on press59.win.
    private static let orange = Color(red: 1, green: 0.42, blue: 0.17)

    var body: some View {
        // What happened comes first; the keys that did it follow as a small chip.
        HStack(spacing: 14) {
            result
                .font(.system(size: 20, weight: .semibold))
            KeyChip(key: key, tint: Self.orange)
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        // As wide as it needs, so long app names aren't cut off.
        .fixedSize()
        .padding(16) // Room for the shadow.
    }

    private var key: String {
        switch keystroke {
        case let .app(key, _, _): key.uppercased()
        case let .window(windowKey, _): windowKey.symbol
        case let .hyper(key): key
        case .settings: HyperKeyState.settingsKey
        }
    }

    @ViewBuilder private var result: some View {
        switch keystroke {
        case let .app(_, appURL, hid):
            HStack(spacing: 8) {
                Image(nsImage: AppIconCache.icon(for: appURL, pointSize: 28))
                    .resizable()
                    .frame(width: 28, height: 28)
                Text(hid ? "Hide \(AppBinding.name(of: appURL))" : AppBinding.name(of: appURL))
                    .lineLimit(1)
            }
        case let .window(_, position):
            Label(position.name, systemImage: "macwindow")
        case let .hyper(key):
            Text("⌃⌥⇧⌘\(key)")
        case .settings:
            Label("Settings", systemImage: "gearshape.fill")
        }
    }
}

/// The shortcut as one small key-shaped chip, e.g. "⇪C", with Caps Lock in Press59's orange.
/// Also used on the month card.
struct KeyChip: View {
    let key: String
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            Text("⇪").foregroundStyle(tint)
            Text(key)
        }
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(Color.primary.opacity(0.6))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12))
        }
    }
}

private extension WindowKey {
    var symbol: String {
        switch self {
        case .left: "←"
        case .right: "→"
        case .up: "↑"
        case .down: "↓"
        case .fill: "↩"
        }
    }
}

private extension WindowPosition {
    /// E.g. "Left half", "Top right" or "Bottom of left third".
    var name: String {
        switch self {
        case .center:
            return "Centered"
        case let .tile(column, row):
            let columnName: String? = switch column {
            case .full: nil
            case .leftHalf: "left"
            case .rightHalf: "right"
            case .leftThird: "left third"
            case .rightThird: "right third"
            }
            switch (row, columnName) {
            case (.full, nil): return "Full screen"
            case let (.full, name?): return name.hasSuffix("third") ? name.capitalizedFirst : "\(name.capitalizedFirst) half"
            case (.top, nil): return "Top half"
            case (.bottom, nil): return "Bottom half"
            case let (.top, name?): return name.hasSuffix("third") ? "Top of \(name)" : "Top \(name)"
            case let (.bottom, name?): return name.hasSuffix("third") ? "Bottom of \(name)" : "Bottom \(name)"
            }
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
