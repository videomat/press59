import AppKit
import SwiftUI

/// Offers shortcuts for the Dock apps that don't have one yet, shown on the cheat sheet keyboard.
/// Each can be left out with a click. Nothing is added unless the person confirms; Return, Not Now
/// and closing the window all decline.
final class DockSuggestionsController: NSObject, NSWindowDelegate {
    private let store: BindingStore
    private var window: NSWindow?
    private var onClose: (() -> Void)?

    init(store: BindingStore) {
        self.store = store
    }

    /// Shows the suggestions, or calls `onClose` right away when there are none.
    func show(onClose: (() -> Void)? = nil) {
        let suggestions = store.dockAppsToAdd
        guard !suggestions.isEmpty else {
            onClose?()
            return
        }
        window?.close()
        self.onClose = onClose

        let view = DockSuggestionsView(existing: store.bindings, suggestions: suggestions) { [weak self] chosen in
            // Add exactly what was chosen, even if the Dock changed while the window was open.
            self?.store.add(chosen)
            self?.window?.close()
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.setContentSize(hosting.view.fittingSize)
        window.title = "Shortcuts for Your Dock Apps"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        let onClose = self.onClose
        self.onClose = nil
        onClose?()
    }
}

struct DockSuggestionsView: View {
    let existing: [AppBinding]
    let suggestions: [AppBinding]
    /// Called with the chosen shortcuts, or none to decline.
    let finish: (_ chosen: [AppBinding]) -> Void

    /// Keys of the suggestions to add; all of them to start with.
    @State private var selected: Set<String>

    init(existing: [AppBinding], suggestions: [AppBinding], finish: @escaping ([AppBinding]) -> Void) {
        self.existing = existing
        self.suggestions = suggestions
        self.finish = finish
        _selected = State(initialValue: Set(suggestions.map(\.key)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add shortcuts for your Dock apps?")
                    .font(.title2.weight(.semibold))
                Text("Each Dock app gets a letter from its name, in orange. Click an app to leave it out. You can change them any time in Settings.")
                    .foregroundStyle(.secondary)
                    .frame(width: 560, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            let suggestedKeys = Set(suggestions.map(\.key))
            ShortcutKeyboard(
                bindings: existing + suggestions,
                newKeys: selected,
                dimmedKeys: suggestedKeys.subtracting(selected),
                tappableKeys: suggestedKeys,
                onTap: toggle
            )
            HStack {
                Spacer()
                Button(selected.count == 1 ? "Add 1 Shortcut" : "Add \(selected.count) Shortcuts") {
                    finish(suggestions.filter { selected.contains($0.key) })
                }
                .disabled(selected.isEmpty)
                Button("Not Now") { finish([]) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        // Take the keyboard's natural size, so the window fits it instead of growing.
        .fixedSize()
    }

    private func toggle(_ key: String) {
        if selected.contains(key) {
            selected.remove(key)
        } else {
            selected.insert(key)
        }
    }
}
