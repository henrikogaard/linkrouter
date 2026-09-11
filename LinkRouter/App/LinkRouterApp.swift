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

        MenuBarExtra {
            MenuBarMenu()
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .accessibilityLabel("LinkRouter")
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarMenu: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings") {
            SettingsPresenter.present { id in
                openWindow(id: id)
            }
        }
        Button("Quit LinkRouter") {
            NSApp.terminate(nil)
        }
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
