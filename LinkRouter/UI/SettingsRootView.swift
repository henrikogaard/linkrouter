import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case browsers, profiles, rules, history, general, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .browsers: String(localized: "Browsers")
        case .profiles: String(localized: "Profiles")
        case .rules: String(localized: "Rules")
        case .history: String(localized: "History")
        case .general: String(localized: "General")
        case .about: String(localized: "About")
        }
    }

    var symbol: String {
        switch self {
        case .browsers: "safari"
        case .profiles: "square.grid.2x2"
        case .rules: "list.bullet.rectangle"
        case .history: "clock"
        case .general: "gearshape"
        case .about: "info.circle"
        }
    }
}

struct SettingsRootView: View {
    @EnvironmentObject private var state: AppState
    @State private var pane: SettingsPane = .browsers

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: selectionBinding) { item in
                Label(item.title, systemImage: item.symbol)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            Group {
                switch pane {
                case .browsers: BrowsersPane()
                case .profiles: ProfilesPane()
                case .rules: RulesPane()
                case .history: HistoryPane()
                case .general: GeneralPane()
                case .about: AboutPane()
                }
            }
            .navigationTitle(pane.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .tint(LR.accent)
        .sheet(isPresented: welcomeBinding) {
            WelcomeView(pane: $pane)
                .environmentObject(state)
        }
        .onAppear {
            state.refreshDefaultStatus()
            state.refreshDiscovered()
        }
    }

    private var selectionBinding: Binding<SettingsPane?> {
        Binding(
            get: { pane },
            set: { if let selection = $0 { pane = selection } }
        )
    }

    private var welcomeBinding: Binding<Bool> {
        Binding(
            get: { !state.settings.onboardingDone },
            set: { shown in
                if !shown, !state.settings.onboardingDone {
                    state.settings.onboardingDone = true
                    state.save()
                }
            }
        )
    }
}
