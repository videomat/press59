import AppKit
import ServiceManagement
import Sparkle
import SwiftUI
import UniformTypeIdentifiers

/// Settings in three tabs, so the shortcuts aren't pushed down by options:
/// Shortcuts (opens first), General and About.
enum SettingsWindow {
    static func make(
        store: BindingStore,
        monitor: HyperKeyMonitor,
        updater: SPUUpdater,
        showGuide: @escaping () -> Void,
        showDockSuggestions: @escaping () -> Void
    ) -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(item(
            "Shortcuts", symbol: "keyboard",
            ShortcutsSettingsView(store: store, monitor: monitor, showDockSuggestions: showDockSuggestions)
        ))
        tabs.addTabViewItem(item("General", symbol: "gearshape", GeneralSettingsView(store: store, showGuide: showGuide)))
        tabs.addTabViewItem(item("About", symbol: "info.circle", AboutSettingsView(updater: updater, showGuide: showGuide)))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private static func item(_ label: String, symbol: String, _ view: some View) -> NSTabViewItem {
        let hosting = NSHostingController(rootView: view)
        // The window's title follows the selected tab.
        hosting.title = label
        // The window takes each tab's own size when it's selected.
        hosting.sizingOptions = .preferredContentSize
        let item = NSTabViewItem(viewController: hosting)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        return item
    }
}

// MARK: - Shortcuts

struct ShortcutsSettingsView: View {
    @ObservedObject var store: BindingStore
    @ObservedObject var monitor: HyperKeyMonitor
    let showDockSuggestions: () -> Void

    var body: some View {
        Form {
            if !monitor.isTrusted {
                Section {
                    LabeledContent {
                        Button("Open Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    } label: {
                        Label("Press59 needs Accessibility access", systemImage: "exclamationmark.triangle.fill")
                        Text("Allow Press59 in Privacy & Security › Accessibility to use Caps Lock as the Hyper key.")
                    }
                }
            }

            Section {
                ForEach($store.bindings) { $binding in
                    HStack {
                        Image(nsImage: binding.icon)
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text(binding.appName)
                        Spacer()
                        Picker("Key", selection: $binding.key) {
                            ForEach(store.freeKeys(including: binding.key), id: \.self) { key in
                                Text("⇪ \(key.uppercased())").tag(key)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                        Button(role: .destructive) {
                            store.remove(binding)
                        } label: {
                            Label("Remove Shortcut", systemImage: "trash")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                        .help("Remove Shortcut")
                    }
                    .contextMenu {
                        Button("Remove Shortcut", role: .destructive) {
                            store.remove(binding)
                        }
                    }
                }
                if store.bindings.isEmpty {
                    Text("No shortcuts yet. Add an app, or start from the apps in your Dock.")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Add App…", action: chooseApp)
                    Button("Add Apps from Dock…", action: showDockSuggestions)
                        .disabled(store.dockAppsToAdd.isEmpty)
                }
            } footer: {
                Text("Hold Caps Lock and press an app’s letter to switch to it.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 440)
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach(store.add(appURL:))
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @ObservedObject var store: BindingStore
    let showGuide: () -> Void
    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchesAtLogin)
                    .onChange(of: launchesAtLogin) { _, enabled in
                        setLaunchesAtLogin(enabled)
                    }
            }

            Section {
                Toggle("Quick tap toggles Caps Lock", isOn: $store.quickTapTogglesCapsLock)
                Toggle("Hide the app if it’s already in front", isOn: $store.hidesFrontmostApp)
                Toggle("Hold Caps Lock to show your shortcuts", isOn: $store.showsCheatSheet)
            } header: {
                Text("Caps Lock")
            }

            Section {
                Toggle("Caps Lock + arrow keys move windows", isOn: $store.movesWindows)
            } header: {
                Text("Windows")
            } footer: {
                Text("← or → for a half, again for a third, then ↑ or ↓ for the top or bottom. Return fills the screen; again, it centers the window. When off, these keys are sent as ⌃⌥⇧⌘ + key.")
            }

            Section {
                Toggle("Show shortcuts on screen as you press them", isOn: $store.showsKeystrokes)
            } header: {
                Text("Recording")
            } footer: {
                Text("For screen recordings, streams and demos: a badge at the bottom of the screen shows each Caps Lock shortcut, so viewers can follow along.")
            }

            Section {
                Button("How Press59 Works…", action: showGuide)
                    .buttonStyle(.link)
            } footer: {
                Text("Menu bar icon hidden? Hold Caps Lock and press , or open Press59 again to get back here.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - About

struct AboutSettingsView: View {
    let updater: SPUUpdater
    let showGuide: () -> Void
    @State private var checksForUpdates = false

    private static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Press59").font(.title2.weight(.semibold))
                        Text("Version \(Self.version)").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Check for Updates") { updater.checkForUpdates() }
                }
                Toggle("Check for updates automatically", isOn: $checksForUpdates)
                    .onChange(of: checksForUpdates) { _, enabled in
                        updater.automaticallyChecksForUpdates = enabled
                    }
            }

            Section {
                Button("How Press59 Works…", action: showGuide)
                    .buttonStyle(.link)
                Link("press59.win", destination: URL(string: "https://press59.win")!)
                Link("Source on GitHub", destination: URL(string: "https://github.com/videomat/press59")!)
            } footer: {
                Text("Free software under the GPL-3.0 license.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { checksForUpdates = updater.automaticallyChecksForUpdates }
    }
}
