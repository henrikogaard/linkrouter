import SwiftUI

@main
struct LinkRouterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var state = AppState.shared

    var body: some Scene {
        Window("LinkRouter", id: "settings") {
            SettingsRootView()
                .environmentObject(state)
                .frame(minWidth: 860, minHeight: 560)
                .preferredColorScheme(state.settings.appearance.colorScheme)
                .background(AboutWindowOpener())
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 920, height: 640)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button("About LinkRouter") {
                    AboutPanel.show()
                }
            }
        }

        Window("About LinkRouter", id: "about") {
            AboutView()
                .preferredColorScheme(state.settings.appearance.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 260, height: 220)

        MenuBarExtra(isInserted: menuBarBinding) {
            MenuBarMenu()
        } label: {
            if state.isPaused {
                Image(systemName: "pause.circle")
                    .renderingMode(.template)
                    .accessibilityLabel("LinkRouter (paused)")
            } else {
                Image("MenuBarIcon")
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
    @Environment(\.openWindow) private var openWindow
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
        Button("Settings") {
            SettingsPresenter.present { id in
                openWindow(id: id)
            }
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

private struct AboutWindowOpener: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .onReceive(NotificationCenter.default.publisher(for: .linkRouterOpenAbout)) { _ in
                openWindow(id: "about")
                NSApp.activate(ignoringOtherApps: true)
            }
    }
}
