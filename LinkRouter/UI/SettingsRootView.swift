import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case browsers, profiles, rules, history, general
    var id: String { rawValue }
    var title: String {
        switch self {
        case .browsers: String(localized: "Browsers")
        case .profiles: String(localized: "Profiles")
        case .rules: String(localized: "Rules")
        case .history: String(localized: "History")
        case .general: String(localized: "General")
        }
    }
    var symbol: String {
        switch self {
        case .browsers: "safari"
        case .profiles: "square.grid.2x2"
        case .rules: "list.bullet.rectangle"
        case .history: "clock"
        case .general: "gearshape"
        }
    }
}

struct SettingsRootView: View {
    @EnvironmentObject private var state: AppState
    @State private var pane: SettingsPane = .browsers

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle()
                .fill(LR.hairline)
                .frame(width: 1)
            Group {
                switch pane {
                case .browsers: BrowsersPane()
                case .profiles: ProfilesPane()
                case .rules: RulesPane()
                case .history: HistoryPane()
                case .general: GeneralPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LR.pageFill)
        }
        .background(LR.pageFill)
        .tint(Color.primary)
        .preferredColorScheme(state.settings.appearance.colorScheme)
        .sheet(isPresented: welcomeBinding) {
            WelcomeView(pane: $pane)
                .environmentObject(state)
        }
        .onAppear {
            state.refreshDefaultStatus()
            state.refreshDiscovered()
        }
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

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ForkMark()
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text("LinkRouter")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Menu bar")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, LR.titlebar + 8)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)

            VStack(spacing: 3) {
                ForEach(SettingsPane.allCases) { item in
                    Button {
                        pane = item
                    } label: {
                        Label(item.title, systemImage: item.symbol)
                            .font(.system(size: 13, weight: pane == item ? .semibold : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                pane == item ? LR.accent.opacity(0.16) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .foregroundStyle(pane == item ? LR.accent : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(pane == item ? .isSelected : [])
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)
        }
        .frame(width: LR.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(LR.sidebarFill)
    }
}

struct PageHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .padding(.top, 8)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, LR.pageInset)
        .padding(.top, LR.titlebar)
        .padding(.bottom, 16)
    }
}

struct DefaultBanner: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        if !state.isDefaultBrowser {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LR.accent)
                    .frame(width: 32, height: 32)
                    .background(LR.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Not the default browser")
                        .font(.system(size: 13, weight: .semibold))
                    Text("System Settings → Desktop & Dock. macOS has to confirm it.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button("Set as default") { state.requestDefault() }
                    .buttonStyle(.borderedProminent)
                    .tint(LR.accent)
                    .controlSize(.regular)
            }
            .padding(14)
            .background(LR.rowFill, in: RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous)
                    .strokeBorder(LR.hairline, lineWidth: 1)
            }
            .padding(.horizontal, LR.pageInset)
            .padding(.bottom, 12)
        }
    }
}

struct PaneFooter<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 8) {
            content
        }
        .controlSize(.regular)
        .padding(.horizontal, LR.pageInset)
        .padding(.vertical, 12)
        .background(LR.pageFill)
        .overlay(alignment: .top) {
            Rectangle().fill(LR.hairline).frame(height: 1)
        }
    }
}
