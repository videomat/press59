import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = BindingStore()
    lazy var monitor = HyperKeyMonitor(store: store)

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Give Caps Lock back to the system when quitting.
        monitor.stop()
    }
}

@main
struct SuperkeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Superkey", systemImage: "capslock.fill") {
            MenuContent(store: appDelegate.store, monitor: appDelegate.monitor)
        }

        Settings {
            SettingsView(store: appDelegate.store, monitor: appDelegate.monitor)
        }
    }
}

private struct MenuContent: View {
    @ObservedObject var store: BindingStore
    @ObservedObject var monitor: HyperKeyMonitor
    @Environment(\.openSettings) private var openSettings

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
        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",")
        Button("Quit Superkey") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
