import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MailPane: View {
    @ObservedObject var state: AppState
    @State private var apps: [MailApp] = []
    @State private var draggingID: String?

    private var orderedApps: [MailApp] {
        let byID = Dictionary(uniqueKeysWithValues: apps.map { ($0.bundleIdentifier, $0) })
        let ordered = state.settings.mail.order.compactMap { byID[$0] }
        return ordered + apps.filter { !state.settings.mail.order.contains($0.bundleIdentifier) }
    }

    private var selection: Binding<String> {
        Binding(get: {
            state.settings.mail.mode == .always ? (state.settings.mail.favouriteBundleID ?? "") : ""
        }, set: { value in
            if value.isEmpty { state.settings.mail.mode = .ask }
            else {
                state.settings.mail.mode = .always
                state.settings.mail.favouriteBundleID = value
            }
            state.save()
        })
    }

    var body: some View {
        Form {
            if !MailCatalog.isDefault() {
                Section {
                    LabeledContent {
                        Button("Set as Default…") { MailCatalog.setDefault { _ in } }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LinkRouter isn't your default email app")
                            Text("Email links only route through LinkRouter once it's the default. macOS asks you to confirm.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Picker("When you click an email link", selection: selection) {
                    Text("Ask Every Time").tag("")
                    ForEach(orderedApps) { app in
                        Text("Always Use \(app.name)").tag(app.bundleIdentifier)
                    }
                }
                ForEach(orderedApps) { app in
                    mailRow(app)
                        .onDrop(of: [UTType.text], delegate: MailRowDropDelegate(
                            targetID: app.id, draggingID: $draggingID, apps: orderedApps,
                            move: moveMailApp
                        ))
                }
            } header: {
                Text("Email")
            } footer: {
                Text("Hold a modifier key while opening a link to show the chooser.")
            }
        }
        .formStyle(.grouped)
        .onAppear { apps = MailCatalog.installed() }
    }

    private func mailRow(_ app: MailApp) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 16)
                .contentShape(Rectangle())
                .help("Drag to reorder")
                .onDrag { draggingID = app.id; return NSItemProvider(object: app.id as NSString) }

            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                .resizable()
                .interpolation(.high)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13))
                if state.settings.mail.favouriteBundleID == app.bundleIdentifier {
                    Text("Default")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("In picker", isOn: Binding(
                get: { !state.settings.mail.disabled.contains(app.bundleIdentifier) },
                set: { enabled in
                    if enabled { state.settings.mail.disabled.remove(app.bundleIdentifier) }
                    else { state.settings.mail.disabled.insert(app.bundleIdentifier) }
                    state.save()
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .accessibilityLabel("Show \(app.name) in the email chooser")

            Menu {
                Button("Make Default") {
                    state.settings.mail.favouriteBundleID = app.bundleIdentifier
                    state.settings.mail.mode = .always
                    state.save()
                }
                Button("Move Up") { move(app, by: -1) }
                    .disabled(orderedApps.first?.id == app.id)
                Button("Move Down") { move(app, by: 1) }
                    .disabled(orderedApps.last?.id == app.id)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Email app actions")
        }
    }

    private func moveMailApp(_ from: String, _ to: String) {
        guard from != to, let fromIndex = orderedApps.firstIndex(where: { $0.id == from }),
              let toIndex = orderedApps.firstIndex(where: { $0.id == to }) else { return }
        var ids = orderedApps.map(\.id)
        ids.remove(at: fromIndex)
        ids.insert(from, at: toIndex)
        state.settings.mail.order = ids
        state.save()
    }

    private func move(_ app: MailApp, by offset: Int) {
        let index = orderedApps.firstIndex(where: { $0.id == app.id })!
        let target = index + offset
        guard orderedApps.indices.contains(target) else { return }
        moveMailApp(app.id, orderedApps[target].id)
    }
}

private struct MailRowDropDelegate: DropDelegate {
    let targetID: String
    @Binding var draggingID: String?
    let apps: [MailApp]
    let move: (String, String) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID else { return }
        move(draggingID, targetID)
    }
    func performDrop(info: DropInfo) -> Bool { draggingID = nil; return true }
}
