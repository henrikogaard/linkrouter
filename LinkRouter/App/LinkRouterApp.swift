import SwiftUI

@main
struct LinkRouterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var state = AppState.shared

    init() {
        SettingsPresenter.makeContent = {
            NSHostingController(
                rootView: SettingsRootView()
                    .environmentObject(AppState.shared)
                    .tint(LR.accent)
                    .frame(minWidth: 860, minHeight: 560)
            )
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
        if !state.isDefaultBrowser {
            Button("Make LinkRouter the default browser…") {
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
            Button("Route Clipboard Link") {
                state.refreshClipboard()
                if let url = ClipboardLink.firstURL(in: NSPasteboard.general.string(forType: .string)) {
                    state.handleIncoming(url)
                }
            }
        } else {
            Text("No link on clipboard")
                .foregroundStyle(.secondary)
        }
        Divider()
        Section("Recent") {
            if state.recent.isEmpty {
                Text("No links routed yet")
            } else {
                ForEach(state.recent.prefix(5)) { entry in
                    Button(recentLabel(entry)) {
                        state.reopen(entry)
                    }
                }
                Button("Clear Recent") {
                    state.clearRecent()
                }
            }
        }
        .onAppear {
            state.refreshDefaultStatus()
        }
        Divider()
        Button("Setup Guide…") {
            state.settings.onboardingDone = false
            SettingsPresenter.present()
        }
        if Updater.shared.canCheck {
            Button("Check for Updates…") {
                Updater.shared.check()
            }
        }
        Button("Settings") {
            SettingsPresenter.present()
        }
        Button("Quit LinkRouter") {
            NSApp.terminate(nil)
        }
    }

    private var pausedLabel: String {
        guard let until = state.pausedUntil else { return "Routing paused" }
        if until == .distantFuture {
            return "Routing paused (until resumed)"
        }
        return "Routing paused (until \(until.formatted(date: .omitted, time: .shortened)))"
    }

    private func recentLabel(_ entry: RoutedEntry) -> String {
        let host = entry.url.host ?? entry.url.absoluteString
        return "\(String(host.prefix(40))) → \(entry.title)"
    }
}
