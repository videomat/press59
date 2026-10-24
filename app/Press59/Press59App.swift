import Sparkle
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = BindingStore()
    lazy var monitor = HyperKeyMonitor(store: store)
    lazy var cheatSheet = CheatSheetController(store: store)
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
            let window = NSWindow(contentViewController: NSHostingController(
                rootView: SettingsView(store: store, monitor: monitor, updater: updaterController.updater,
                                       showGuide: showGuide, showDockSuggestions: showDockSuggestions)
            ))
            window.title = "Press59 Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
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
                showGuide: appDelegate.showGuide
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

    var body: some View {
        if !monitor.isTrusted {
            Text("Waiting for Accessibility access…")
            Divider()
        }
        ForEach(store.bindings.sorted { $0.key < $1.key }) { binding in
            Text("⇪ \(binding.key.uppercased())   \(binding.appName)")
        }
        if !store.bindings.isEmpty {
            Divider()
        }
        Button("Settings…", action: showSettings)
            .keyboardShortcut(",")
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
