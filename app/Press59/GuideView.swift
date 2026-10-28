import SwiftUI

/// How Press59 works: switching apps, the cheat sheet, moving windows and the other keys.
/// Opened from the menu, from Settings and once on first launch.
struct GuideView: View {
    var body: some View {
        ScrollView {
            GuideContent()
        }
        .frame(width: 520, height: 640)
    }
}

struct GuideContent: View {
    var body: some View {
            VStack(alignment: .leading, spacing: 26) {
                GuideSection(title: "Switch apps", keys: ["⇪", "C"]) {
                    Text("Hold Caps Lock and press an app’s letter. Already open, it comes to the front; not running, it opens. The same keys again hide it. Pick the letters in Settings.")
                }
                GuideSection(title: "See your shortcuts", keys: ["⇪"]) {
                    Text("Hold Caps Lock on its own for half a second and your shortcuts show up on a keyboard. Let go to close it, or click a key to give it an app: the one you’re in, another open app, or any app. Once it’s open, you can also type a key. Escape closes it.")
                }
                GuideSection(title: "Move windows", keys: ["⇪", "←", "→", "↑", "↓", "↩"]) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Hold Caps Lock and press arrows. They build on each other: ← or → picks a side, again for a third, then ↑ or ↓ for the top or bottom of it. Return fills the screen from anywhere; again, it centers the window.")
                        Grid(horizontalSpacing: 18, verticalSpacing: 14) {
                            ForEach(0..<2) { row in
                                GridRow {
                                    ForEach(Self.layouts[(row * 4)..<(row * 4 + 4)], id: \.keys) { layout in
                                        LayoutExample(keys: layout.keys, position: layout.position)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                GuideSection(title: "Everything else", keys: ["⇪", "⌘"]) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tap Caps Lock quickly on its own to type capitals, as before.")
                        Text("Caps Lock + any key without an app is sent as ⌃⌥⇧⌘ + key, a shortcut no other app uses, for Raycast, Alfred or your own scripts.")
                        Text("Caps Lock + , opens Settings, even when the menu bar icon is hidden.")
                    }
                }
            }
            .padding(28)
            .frame(width: 520)
    }

    private static let layouts: [(keys: [String], position: WindowPosition)] = [
        (["←"], .leftHalf),
        (["←", "←"], .tile(.leftThird, .full)),
        (["←", "↑"], .tile(.leftHalf, .top)),
        (["←", "←", "↓"], .tile(.leftThird, .bottom)),
        (["↑"], .tile(.full, .top)),
        (["↓"], .tile(.full, .bottom)),
        (["↩"], .fill),
        (["↩", "↩"], .center),
    ]
}

private struct GuideSection<Content: View>: View {
    let title: String
    let keys: [String]
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(title).font(.title3.weight(.semibold))
                Spacer()
                HStack(spacing: 4) {
                    ForEach(keys, id: \.self) { KeyCap(label: $0) }
                }
            }
            content
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct KeyCap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .frame(minWidth: 22, minHeight: 22)
            .padding(.horizontal, 3)
            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.primary.opacity(0.15)))
    }
}

/// A small screen with the window where `keys` put it, drawn with the same layout code that moves windows.
private struct LayoutExample: View {
    let keys: [String]
    let position: WindowPosition

    private static let screen = CGRect(x: 0, y: 0, width: 96, height: 60)
    /// Press59's orange, as in the app icon and on press59.win.
    private static let orange = Color(red: 1, green: 0.42, blue: 0.17)

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.primary.opacity(0.15)))
                let frame = window
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Self.orange)
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
            }
            .frame(width: Self.screen.width, height: Self.screen.height)
            Text("⇪ " + keys.joined(separator: " "))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
        }
    }

    /// The window's frame inset a little from the screen edges, flipped to SwiftUI's top-left origin.
    private var window: CGRect {
        let inset = Self.screen.insetBy(dx: 3, dy: 3)
        let frame = position.frame(in: inset).insetBy(dx: 1, dy: 1)
        return CGRect(x: frame.minX, y: Self.screen.height - frame.maxY, width: frame.width, height: frame.height)
    }
}
