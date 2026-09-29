import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var state: AppState
    @Binding var pane: SettingsPane
    @Environment(\.dismiss) private var dismiss
    @State private var loginOn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ForkMark()
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to LinkRouter")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Four quick steps and you're set.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                checklistRow(
                    done: state.isDefaultBrowser,
                    title: "Make LinkRouter your default browser",
                    button: "Set as default"
                ) {
                    state.requestDefault()
                }
                checklistRow(
                    done: !state.enabledRows.isEmpty,
                    title: "Browsers found: \(state.enabledRows.count)",
                    button: "Refresh"
                ) {
                    state.refreshDiscovered()
                }
                checklistRow(
                    done: state.favourite != nil,
                    title: "Pick a favourite",
                    button: "Open Browsers"
                ) {
                    dismiss()
                    pane = .browsers
                }
                HStack(spacing: 10) {
                    Image(systemName: loginOn ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(loginOn ? Color.primary : Color.secondary)
                        .font(.system(size: 15, weight: .semibold))
                    Text("Open at login")
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("Open at login", isOn: $loginOn)
                        .labelsHidden()
                        .accessibilityLabel("Open at login")
                        .toggleStyle(.switch)
                        .tint(LR.accent)
                        .onChange(of: loginOn) { _, value in
                            state.setLoginItem(value)
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(LR.rowFill, in: RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous))
            }

            HStack {
                Button("Skip") { finish() }
                Spacer()
                Button("Done") { finish() }
                    .buttonStyle(.borderedProminent)
                    .tint(LR.accent)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            loginOn = state.loginItemOn
            state.refreshDefaultStatus()
        }
    }

    private func checklistRow(done: Bool, title: String, button: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.primary : Color.secondary)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(.system(size: 13))
            Spacer()
            Button(button, action: action)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(LR.rowFill, in: RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous))
    }

    private func finish() {
        state.settings.onboardingDone = true
        state.save()
        dismiss()
    }
}
