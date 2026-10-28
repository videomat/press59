import Sparkle
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = BindingStore()
    lazy var monitor = HyperKeyMonitor(store: store)
    lazy var cheatSheet = CheatSheetController(store: store)
    let keystrokeOverlay = KeystrokeOverlayController()
    let usage = UsageStore()
    lazy var monthWindow = MonthWindowController(usage: usage, store: store)
    lazy var dockSuggestions = DockSuggestionsController(store: store)
    /// Checks press59.win/appcast.xml for new versions and installs them (Sparkle).
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )
    private var settingsWindow: NSWindow?
    private var guideWindow: NSWindow?
    private static let hasShownGuideKey = "hasShownGuide"

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.onOpenSettings = { [weak self] in self?.showSettings() }
        monitor.onShowCheatSheet = { [weak self] in self?.cheatSheet.show() }
        monitor.onHideCheatSheet = { [weak self] in self?.cheatSheet.hide() }
        monitor.onShortcut = { [weak self] keystroke in
            guard let self else { return }
            if store.keepsUsageStats { usage.record(keystroke) }
            if store.showsKeystrokes { keystrokeOverlay.show(keystroke) }
        }
        monitor.start()
        // On first launch, offer shortcuts for the Dock apps, then explain how it works.
        // The guide also shows once to people updating from before it existed.
        if store.isFirstLaunch {
            dockSuggestions.show(onClose: { [weak self] in self?.showGuideOnce() })
        } else {
            showGuideOnce()
        }
    }

    private func showGuideOnce() {
        guard !UserDefaults.standard.bool(forKey: Self.hasShownGuideKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.hasShownGuideKey)
        showGuide()
    }

    func showDockSuggestions() {
        dockSuggestions.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Give Caps Lock back to the system when quitting.
        monitor.stop()
    }

    /// Opening Press59 again while it's running (Spotlight, Finder, a launcher) shows Settings,
    /// since macOS may hide the menu bar icon when the menu bar is crowded.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    /// Settings live in an AppKit-owned window so they can be opened from anywhere,
    /// not only from a SwiftUI view.
    func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow.make(
                store: store,
                monitor: monitor,
                usage: usage,
                updater: updaterController.updater,
                showGuide: showGuide,
                showMonth: { [weak self] in self?.showMonth() },
                showDockSuggestions: showDockSuggestions
            )
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func showGuide() {
        if guideWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: GuideView()))
            window.title = "How Press59 Works"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            guideWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        guideWindow?.makeKeyAndOrderFront(nil)
    }

    /// "Your October with Press59", the month card to share.
    func showMonth() {
        monthWindow.show()
    }
}

@main
struct Press59App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(
                store: appDelegate.store,
                monitor: appDelegate.monitor,
                updater: appDelegate.updaterController.updater,
                showSettings: appDelegate.showSettings,
                showGuide: appDelegate.showGuide,
                showMonth: appDelegate.showMonth
            )
        } label: {
            Image("MenuBarIcon")
                .accessibilityLabel("Press59")
        }
    }
}

private struct MenuContent: View {
    @ObservedObject var store: BindingStore
    @ObservedObject var monitor: HyperKeyMonitor
    let updater: SPUUpdater
    let showSettings: () -> Void
    let showGuide: () -> Void
    let showMonth: () -> Void

    var body: some View {
        if !monitor.isTrusted {
            Text("Waiting for Accessibility access…")
            Divider()
        }
        // A pointer to the cheat sheet rather than a list of every shortcut, which would only grow.
        Text(store.showsCheatSheet ? "Hold ⇪ Caps Lock to see your shortcuts" : "Your shortcuts are in Settings")
        Divider()
        // Here too, to turn it on quickly before a recording.
        Toggle("Show Shortcuts on Screen", isOn: $store.showsKeystrokes)
        Divider()
        Button("Settings…", action: showSettings)
            .keyboardShortcut(",")
        Button("Your Month…", action: showMonth)
        Button("How Press59 Works…", action: showGuide)
        Button("Check for Updates…") {
            // Sparkle's window opens behind other apps unless the menu bar app comes forward.
            NSApp.activate(ignoringOtherApps: true)
            updater.checkForUpdates()
        }
        Button("Quit Press59") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
