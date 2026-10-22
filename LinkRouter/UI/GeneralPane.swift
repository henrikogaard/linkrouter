import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct GeneralPane: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var updater = Updater.shared
    @State private var loginOn = false
    @State private var htmlIsDefault = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Default web browser") {
                    if state.isDefaultBrowser {
                        HStack(spacing: 6) {
                            Text("LinkRouter")
                                .foregroundStyle(.secondary)
                            Image(systemName: "checkmark")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Set as Default…") { state.requestDefault() }
                    }
                }

                LabeledContent("HTML files") {
                    if htmlIsDefault {
                        HStack(spacing: 6) {
                            Text("LinkRouter")
                                .foregroundStyle(.secondary)
                            Image(systemName: "checkmark")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Open with LinkRouter") {
                            NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: .html) { error in
                                DispatchQueue.main.async {
                                    if let error {
                                        Log.routing.error("Could not set HTML file handler: \(error.localizedDescription)")
                                    }
                                    refreshHTMLDefault()
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Default Browser")
            } footer: {
                Button("Open Desktop & Dock Settings…") {
                    DefaultBrowser.openSystemSettings()
                }
                .buttonStyle(.link)
            }

            Section {
                Toggle(isOn: $state.settings.forcePromptOnModifier) {
                    settingLabel(
                        "Ask when a modifier key is held",
                        subtitle: "Hold Shift, Control, Option or Command while a link opens to always show the picker."
                    )
                }
                .toggleStyle(.switch)
                .onChange(of: state.settings.forcePromptOnModifier) { _, _ in state.save() }

                Picker(selection: $state.settings.promptTimeout) {
                    Text("Never").tag(0)
                    Text("15 seconds").tag(15)
                    Text("30 seconds").tag(30)
                    Text("60 seconds").tag(60)
                } label: {
                    settingLabel(
                        "Close automatically after",
                        subtitle: "When it closes, the link opens in your favourite browser."
                    )
                }
                .pickerStyle(.menu)
                .onChange(of: state.settings.promptTimeout) { _, _ in state.save() }

                Toggle(isOn: $state.settings.openInBackground) {
                    settingLabel(
                        "Open browsers in the background",
                        subtitle: "Keep focus in the app you clicked from."
                    )
                }
                .toggleStyle(.switch)
                .onChange(of: state.settings.openInBackground) { _, _ in state.save() }
            } header: {
                Text("Picker")
            }

            Section("Link Cleaning") {
                Toggle(isOn: $state.settings.unwrapRedirects) {
                    settingLabel(
                        "Unwrap redirect links",
                        subtitle: "Follows known redirectors (Google /url, Outlook SafeLinks, Facebook l.php) to the real URL before routing."
                    )
                }
                .toggleStyle(.switch)
                .onChange(of: state.settings.unwrapRedirects) { _, _ in state.save() }

                Toggle(isOn: $state.settings.expandShortLinks) {
                    settingLabel(
                        "Expand short links",
                        subtitle: "Looks up where t.co, bit.ly and similar links lead, so rules match the real site. The short-link service sees the lookup."
                    )
                }
                .toggleStyle(.switch)
                .onChange(of: state.settings.expandShortLinks) { _, _ in state.save() }

                Toggle(isOn: $state.settings.stripTrackingParams) {
                    settingLabel(
                        "Remove tracking parameters",
                        subtitle: "Removes utm_* and common click IDs (fbclid, gclid, …) before routing."
                    )
                }
                .toggleStyle(.switch)
                .onChange(of: state.settings.stripTrackingParams) { _, _ in state.save() }
            }

            Section("Appearance") {
                Picker("Appearance", selection: appearanceBinding) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                Toggle(isOn: $state.settings.showMenuBar) {
                    settingLabel(
                        "Show in menu bar",
                        subtitle: "When hidden, open LinkRouter from Finder or Spotlight to get back here."
                    )
                }
                .toggleStyle(.switch)
                .onChange(of: state.settings.showMenuBar) { _, _ in state.save() }
            }

            Section("Startup") {
                Toggle(isOn: $loginOn) {
                    Text("Open at login")
                }
                .toggleStyle(.switch)
                .onChange(of: loginOn) { _, value in state.setLoginItem(value) }
            }

            Section("Updates") {
                LabeledContent("Version") {
                    HStack(spacing: 8) {
                        Text(version)
                            .foregroundStyle(.secondary)
                        if updater.canCheck {
                            Button("Check for Updates…") { updater.check() }
                        }
                    }
                }
                if updater.canCheck {
                    Toggle("Check for updates automatically", isOn: autoUpdateBinding)
                        .toggleStyle(.switch)
                } else {
                    Text("Updates aren't configured for this build")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                LabeledContent("Settings") {
                    HStack {
                        Button("Export…") { exportSettings() }
                        Button("Import…") { importSettings() }
                    }
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("Includes browsers, rules, profiles and settings. Link history isn't included.")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loginOn = state.loginItemOn
            state.refreshDefaultStatus()
            refreshHTMLDefault()
        }
    }

    private func refreshHTMLDefault() {
        let appURL = NSWorkspace.shared.urlForApplication(toOpen: .html)
        htmlIsDefault = appURL?.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL
    }

    private func settingLabel(_ title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var autoUpdateBinding: Binding<Bool> {
        Binding(
            get: { updater.automaticallyChecksForUpdates },
            set: { updater.automaticallyChecksForUpdates = $0 }
        )
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

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "LinkRouter-settings.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try state.exportSettings().write(to: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = String(localized: "Couldn't export settings")
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let confirm = NSAlert()
        confirm.messageText = String(localized: "Replace your current browsers, rules and profiles?")
        confirm.informativeText = String(localized: "Link history is kept. This can't be undone.")
        confirm.addButton(withTitle: String(localized: "Replace"))
        confirm.addButton(withTitle: String(localized: "Cancel"))
        guard confirm.runModal() == .alertFirstButtonReturn else { return }
        do {
            try state.importSettings(from: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = String(localized: "Couldn't import settings")
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: String(localized: "OK"))
            alert.runModal()
        }
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
