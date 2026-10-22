import AppKit
import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var state: AppState
    @Binding var pane: SettingsPane
    @Environment(\.dismiss) private var dismiss
    @State private var loginOn = false

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                    .padding(.bottom, 2)
                Text("Welcome to LinkRouter")
                    .font(.system(size: 17, weight: .semibold))
                Text("Pick a browser for every link.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            Form {
                Section {
                    LabeledContent {
                        if state.isDefaultBrowser {
                            Text("Done")
                                .foregroundStyle(.secondary)
                        } else {
                            Button("Set as Default…") { state.requestDefault() }
                        }
                    } label: {
                        statusLabel(done: state.isDefaultBrowser, title: "Make LinkRouter your default browser")
                    }

                    LabeledContent {
                        Button("Open Browsers") {
                            dismiss()
                            pane = .browsers
                        }
                    } label: {
                        statusLabel(
                            done: state.favourite != nil,
                            title: "Choose your favourite browser",
                            subtitle: "Found \(state.rows.count) browsers"
                        )
                    }

                    LabeledContent {
                        Toggle("Open at login", isOn: $loginOn)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .accessibilityLabel("Open at login")
                            .onChange(of: loginOn) { _, value in state.setLoginItem(value) }
                    } label: {
                        statusLabel(done: loginOn, title: "Open at login")
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .frame(height: 188)

            HStack {
                Spacer()
                Button("Done", action: finish)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(LR.accent)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            loginOn = state.loginItemOn
            state.refreshDefaultStatus()
        }
    }

    private func statusLabel(
        done: Bool,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.primary : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func finish() {
        state.settings.onboardingDone = true
        state.save()
        dismiss()
    }
}
