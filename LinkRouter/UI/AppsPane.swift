import AppKit
import SwiftUI

struct AppsPane: View {
    @EnvironmentObject private var state: AppState

    private struct InstalledHandler: Identifiable {
        let handler: AppLinkHandler
        let appURL: URL

        var id: String { handler.id }
    }

    private var installedHandlers: [InstalledHandler] {
        AppLinks.all.compactMap { handler in
            guard let appURL = AppLinks.applicationURL(for: handler) else { return nil }
            return InstalledHandler(handler: handler, appURL: appURL)
        }
    }

    private var notInstalledHandlers: [AppLinkHandler] {
        let installed = Set(installedHandlers.map(\.id))
        return AppLinks.all.filter { !installed.contains($0.id) }
    }

    var body: some View {
        Form {
            if installedHandlers.isEmpty {
                ContentUnavailableView(
                    "No supported apps installed",
                    systemImage: "app.badge",
                    description: Text("Install a supported app to route its links.")
                )
                .frame(maxWidth: .infinity)
            } else {
                Section {
                    ForEach(installedHandlers) { item in
                        HStack(spacing: 12) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: item.appURL.path))
                                .resizable()
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.handler.name)
                                Text(item.handler.examples)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 12)
                            Toggle(item.handler.name, isOn: enabledBinding(for: item.handler))
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                        .padding(.vertical, 3)
                    }
                } header: {
                    Text("Installed apps")
                } footer: {
                    Text("Links for these apps open in the app instead of a browser. Hold a modifier key to choose a browser instead.")
                }
            }

            if !notInstalledHandlers.isEmpty {
                Section {
                    ForEach(notInstalledHandlers, id: \.id) { handler in
                        Text(handler.name)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Supported apps")
                } footer: {
                    Text("Install one of these to route its links.")
                }
            }
        }
        .formStyle(.grouped)
    }

    private func enabledBinding(for handler: AppLinkHandler) -> Binding<Bool> {
        Binding(
            get: { !state.settings.appLinksDisabled.contains(handler.id) },
            set: { enabled in
                if enabled {
                    state.settings.appLinksDisabled.remove(handler.id)
                } else {
                    state.settings.appLinksDisabled.insert(handler.id)
                }
                state.save()
            }
        )
    }
}
