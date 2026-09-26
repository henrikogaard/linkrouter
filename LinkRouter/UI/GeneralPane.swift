import SwiftUI

struct GeneralPane: View {
    @EnvironmentObject private var state: AppState
    @State private var loginOn = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    title: "General",
                    subtitle: "Default browser, login, and how links open."
                )

                DefaultBanner()

                settingsGroup("Appearance") {
                    Picker("Appearance", selection: appearanceBinding) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Text("System follows macOS. Light and Dark lock this window and the picker.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                settingsGroup("Default browser") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(state.isDefaultBrowser ? "LinkRouter is the default" : "Not the default")
                            .foregroundStyle(state.isDefaultBrowser ? Color.secondary : LR.accent)
                    }
                    Button("Set as default") { state.requestDefault() }
                    Button("Open System Settings") { DefaultBrowser.openSystemSettings() }
                    Text("System Settings → Desktop & Dock → Default web browser")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }

                settingsGroup("Opening links") {
                    Toggle("Force prompt when a modifier key is held", isOn: $state.settings.forcePromptOnModifier)
                        .toggleStyle(.switch)
                        .tint(LR.accent)
                        .onChange(of: state.settings.forcePromptOnModifier) { _, _ in state.save() }
                    Text("Uses currently held Shift, Control, Option, or Command. Not the keys from the original click.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Toggle("Open browsers in the background", isOn: $state.settings.openInBackground)
                        .toggleStyle(.switch)
                        .tint(LR.accent)
                        .onChange(of: state.settings.openInBackground) { _, _ in state.save() }
                }

                settingsGroup("Link cleaning") {
                    Toggle("Unwrap redirect links", isOn: $state.settings.unwrapRedirects)
                        .toggleStyle(.switch)
                        .tint(LR.accent)
                        .onChange(of: state.settings.unwrapRedirects) { _, _ in state.save() }
                    Text("Follows known redirectors (Google /url, Outlook SafeLinks, Facebook l.php) to the real URL before routing.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Toggle("Strip tracking parameters", isOn: $state.settings.stripTrackingParams)
                        .toggleStyle(.switch)
                        .tint(LR.accent)
                        .onChange(of: state.settings.stripTrackingParams) { _, _ in state.save() }
                    Text("Removes utm_* and common click IDs (fbclid, gclid, …) before routing.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                settingsGroup("Menu bar") {
                    Toggle("Show menu bar icon", isOn: $state.settings.showMenuBar)
                        .toggleStyle(.switch)
                        .tint(LR.accent)
                        .onChange(of: state.settings.showMenuBar) { _, _ in state.save() }
                    Text("With the icon hidden, open LinkRouter again from Finder or Spotlight to reach Settings.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                settingsGroup("Login") {
                    Toggle("Open at login", isOn: $loginOn)
                        .toggleStyle(.switch)
                        .tint(LR.accent)
                        .onChange(of: loginOn) { _, value in
                            state.setLoginItem(value)
                        }
                    Text("macOS may ask you to allow a login item.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                settingsGroup("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(version)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.bottom, 28)
        }
        .background(LR.pageFill)
        .onAppear {
            loginOn = state.loginItemOn
            state.refreshDefaultStatus()
        }
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LR.rowFill, in: RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous)
                    .strokeBorder(LR.hairline, lineWidth: 1)
            }
        }
        .padding(.horizontal, LR.pageInset)
    }

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(
            get: { state.settings.appearance },
            set: { value in
                state.settings.appearance = value
                value.apply()
                state.save()
            }
        )
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
