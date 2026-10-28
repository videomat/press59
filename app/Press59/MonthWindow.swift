import AppKit
import SwiftUI

/// "Your October with Press59" in a small window under the menu bar: the card at two thirds of its
/// size, earlier months a click (or ← and →) away, and ways to post or share it.
final class MonthWindowController {
    private let usage: UsageStore
    private let store: BindingStore
    private let selection = MonthSelection()
    private var window: NSWindow?

    init(usage: UsageStore, store: BindingStore) {
        self.usage = usage
        self.store = store
    }

    /// Opens the window on this month.
    func show() {
        selection.month = Calendar.current.startOfMonth(for: Date())
        if window == nil {
            let hosting = NSHostingController(rootView: MonthView(usage: usage, store: store, selection: selection))
            hosting.sizingOptions = .preferredContentSize
            let window = NSWindow(contentViewController: hosting)
            window.title = "Your Month in Press59"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            self.window = window
        }
        guard let window else { return }
        if !window.isVisible {
            // Sized to its content first: placed at a smaller size, it would grow up past the menu bar.
            window.layoutIfNeeded()
            if let content = window.contentViewController?.view {
                window.setContentSize(content.fittingSize)
            }
            placeUnderMenuBar(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Top right of the screen with the mouse pointer, near the menu bar icon it was opened from.
    private func placeUnderMenuBar(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        window.setFrameTopLeftPoint(NSPoint(x: visible.maxX - window.frame.width - 16, y: visible.maxY - 8))
    }
}

/// Which month the window shows.
final class MonthSelection: ObservableObject {
    @Published var month = Calendar.current.startOfMonth(for: Date())
}

struct MonthView: View {
    @ObservedObject var usage: UsageStore
    @ObservedObject var store: BindingStore
    @ObservedObject var selection: MonthSelection
    /// The card as a PNG, for the share button.
    @State private var cardFile: URL?
    /// Shown after posting copies the card, since the site can't be handed the image itself.
    @State private var showsPasteHint = false

    /// How big the card shows here, small but readable; the shared image is full size.
    private static let scale: CGFloat = 2 / 3
    private static let cardSize = MonthCard.size * scale

    /// Newest first.
    private var months: [Date] { usage.monthsToShow }
    private var index: Int { months.firstIndex(of: selection.month) ?? 0 }

    private var sharing: MonthCardSharing? {
        guard let month = usage.log.month(for: selection.month), month.total > 0 else { return nil }
        return MonthCardSharing(monthStart: selection.month, usage: month, keyForApp: { [store] path in
            store.bindings.first { $0.appURL.path == path }?.key
        })
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { selection.month = months[index + 1] } label: {
                    Image(systemName: "chevron.left")
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(index + 1 >= months.count)
                .help("Previous Month")
                Spacer()
                Text(MonthCard.title(for: selection.month, withYear: true))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { selection.month = months[index - 1] } label: {
                    Image(systemName: "chevron.right")
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(index == 0)
                .help("Next Month")
            }
            .buttonStyle(.borderless)

            // The same size with or without a card, so the window doesn't jump between months.
            Group {
                if let sharing {
                    sharing.card
                        .scaleEffect(Self.scale, anchor: .topLeading)
                } else {
                    Text(store.keepsUsageStats
                        ? "Nothing counted in \(MonthCard.title(for: selection.month)). Switch apps with Caps Lock and your month shows up here."
                        : "Counting is off. Turn it on in Settings › General to see your month here.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(32)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.primary.opacity(0.05))
                }
            }
            .frame(width: Self.cardSize, height: Self.cardSize, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 6) {
                Menu("Post") {
                    ForEach(PostSite.allCases, id: \.self) { site in
                        Button("Post on \(site.name)") {
                            sharing?.post(on: site)
                            showsPasteHint = true
                        }
                    }
                }
                .fixedSize()
                if let cardFile {
                    ShareLink("Share…", item: cardFile)
                } else {
                    Button("Share…") {}
                }
                Button("Copy") { sharing?.copyImage() }
                #if DEBUG
                // Handy while working on the card; people post, share or copy it instead.
                Button("Save…") { sharing?.saveImage() }
                #endif
            }
            .disabled(sharing == nil)

            Text(showsPasteHint ? "Image copied. Paste it into your post with ⌘V." : " ")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: Self.cardSize + 32)
        .task(id: "\(selection.month.timeIntervalSince1970)-\(usage.log.month(for: selection.month)?.total ?? 0)") {
            cardFile = sharing?.writeFile()
            showsPasteHint = false
        }
    }
}
