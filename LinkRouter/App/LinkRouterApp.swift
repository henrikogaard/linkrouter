import SwiftUI

@main
struct LinkRouterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var state = AppState.shared

    init() {
        SettingsPresenter.makeContent = {
            let controller = NSHostingController(
                rootView: SettingsRootView()
                    .environmentObject(AppState.shared)
                    .tint(LR.accent)
                    .frame(minWidth: 720, minHeight: 480)
            )
            controller.sceneBridgingOptions = [.toolbars, .title]
            return controller
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button("About LinkRouter") {
                    AboutPanel.show()
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    SettingsPresenter.present()
                }
                .keyboardShortcut(",")
            }
        }

        MenuBarExtra(isInserted: menuBarBinding) {
            MenuBarMenu()
        } label: {
            if state.isPaused {
                Image(systemName: "pause.circle")
                    .renderingMode(.template)
                    .accessibilityLabel("LinkRouter (paused)")
            } else {
                Image(systemName: "arrow.triangle.branch")
                    .renderingMode(.template)
                    .accessibilityLabel("LinkRouter")
            }
        }
        .menuBarExtraStyle(.menu)
    }

    private var menuBarBinding: Binding<Bool> {
        Binding(
            get: { state.settings.showMenuBar },
            set: { value in
                guard value != state.settings.showMenuBar else { return }
                DispatchQueue.main.async {
                    state.settings.showMenuBar = value
                    state.save()
                }
            }
        )
    }
}

private struct MenuBarMenu: View {
    @ObservedObject private var state = AppState.shared

    var body: some View {
        Group {
            if !state.isDefaultBrowser {
                Button("Set LinkRouter as Default Browser…") {
                    state.requestDefault()
                }
                Divider()
            }
            if state.isPaused {
                Text(pausedLabel)
                    .foregroundStyle(.secondary)
                Button("Resume Routing") {
                    state.resume()
                }
            } else {
                Menu("Pause Routing") {
                    Button("For 15 minutes") { state.pause(for: 15 * 60) }
                    Button("For 1 hour") { state.pause(for: 60 * 60) }
                    Button("Until resumed") { state.pause(for: nil) }
                }
            }
            if state.clipboardURL != nil {
                Button("Open Link from Clipboard") {
                    state.refreshClipboard()
                    if let url = ClipboardLink.firstURL(in: NSPasteboard.general.string(forType: .string)) {
                        state.handleIncoming(url)
                    }
                }
            }
            Divider()
            if !state.recent.isEmpty {
                Section("Recent") {
                    ForEach(state.recent.prefix(5)) { entry in
                        Button(recentLabel(entry)) {
                            state.reopen(entry)
                        }
                    }
                    Button("Clear Recent") {
                        state.clearRecent()
                    }
                }
                Divider()
            }
            Button("Settings…") {
                SettingsPresenter.present()
            }
            .keyboardShortcut(",")
            Button("Setup Guide…") {
                state.settings.onboardingDone = false
                SettingsPresenter.present()
            }
            if Updater.shared.canCheck {
                Button("Check for Updates…") {
                    Updater.shared.check()
                }
            }
            Button("About LinkRouter") {
                AboutPanel.show()
            }
            Divider()
            Button("Quit LinkRouter") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .onAppear { state.refreshDefaultStatus() }
    }

    private var pausedLabel: String {
        guard let until = state.pausedUntil else { return "Routing paused" }
        if until == .distantFuture {
            return String(localized: "Routing paused (until resumed)")
        }
        return String(localized: "Routing paused until \(until.formatted(date: .omitted, time: .shortened))")
    }

    private func recentLabel(_ entry: RoutedEntry) -> String {
        let host = entry.url.host ?? entry.url.absoluteString
        return String(localized: "\(String(host.prefix(40))) → \(entry.title)")
    }
}
