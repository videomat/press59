import ServiceManagement
import Sparkle
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: BindingStore
    @ObservedObject var monitor: HyperKeyMonitor
    let updater: SPUUpdater
    let showGuide: () -> Void
    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @State private var checksForUpdates = false

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
                LabeledContent("Version \(Self.version)") {
                    Button("Check Now") { updater.checkForUpdates() }
                }
                Toggle("Check for updates automatically", isOn: $checksForUpdates)
                    .onChange(of: checksForUpdates) { _, enabled in
                        updater.automaticallyChecksForUpdates = enabled
                    }
            }

            Section {
                Toggle("Launch at login", isOn: $launchesAtLogin)
                    .onChange(of: launchesAtLogin) { _, enabled in
                        setLaunchesAtLogin(enabled)
                    }
                Toggle("Hide the app if it’s already in front", isOn: $store.hidesFrontmostApp)
                Toggle("Quick tap toggles Caps Lock", isOn: $store.quickTapTogglesCapsLock)
                Toggle("Hold Caps Lock to show your shortcuts", isOn: $store.showsCheatSheet)
                Toggle("Caps Lock + arrow keys move windows", isOn: $store.movesWindows)
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hold Caps Lock and press a key to open an app. Menu bar icon hidden? Hold Caps Lock and press , or open Press59 again to get back here.")
                    Button("How Press59 Works…", action: showGuide)
                        .buttonStyle(.link)
                }
            }

            Section("Shortcuts") {
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
                HStack {
                    Button("Add App…", action: chooseApp)
                    Button("Add Apps from Dock", action: store.addDockApps)
                        .disabled(store.dockAppsToAdd.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .frame(minHeight: 360)
        .onAppear { checksForUpdates = updater.automaticallyChecksForUpdates }
    }

    private static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach(store.add(appURL:))
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
