import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct BrowsersPane: View {
    @EnvironmentObject private var state: AppState
    @State private var draggingID: UUID?
    @State private var dropTargeted = false

    var body: some View {
        Form {
            if !state.isDefaultBrowser {
                Section {
                    LabeledContent {
                        Button("Set as Default…") { state.requestDefault() }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LinkRouter isn't your default browser")
                            Text("Links only route through LinkRouter once it's the default. macOS asks you to confirm.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                if state.rows.isEmpty {
                    Text("No browsers found.")
                        .foregroundStyle(.secondary)
                }
                ForEach(state.rows) { row in
                    BrowserRow(
                        row: row,
                        draggingID: $draggingID,
                        move: state.moveRow
                    )
                }
            } footer: {
                Text("The first browser is your favourite: it's preselected in the picker and used when the picker times out. Drag to reorder.")
            }
        }
        .formStyle(.grouped)
        .onDrop(of: [.application], isTargeted: $dropTargeted, perform: handleDrop)
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        Color.secondary.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
                    .padding(10)
                    .allowsHitTesting(false)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Browser from Applications…", action: pickApp)
                    Menu("Browser Profile") {
                        profileMenu
                    }
                    Menu("Private Window") {
                        privateMenu
                    }
                    Divider()
                    Button("Refresh Browser List", action: state.refreshDiscovered)
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
    }

    private var profileMenu: some View {
        let hosts = state.chromiumHosts()
        return Group {
            ForEach(hosts) { host in
                if let family = ProfileReader.family(for: host.bundleIdentifier) {
                    let profiles = ProfileReader.chromeProfiles(family: family)
                    if profiles.isEmpty {
                        Text("No \(family.shortName) profiles found")
                    } else {
                        ForEach(profiles, id: \.directory) { profile in
                            Button(hosts.count > 1 ? "\(family.shortName) · \(profile.name)" : profile.name) {
                                state.addChromeProfile(profile, browserID: host.id, isPrivate: false)
                            }
                        }
                    }
                }
            }
            if let firefox = state.firefoxHost() {
                let profiles = ProfileReader.firefoxProfiles(appURL: firefox.bundleURL)
                if profiles.isEmpty {
                    Text("No Firefox profiles found")
                } else {
                    ForEach(profiles, id: \.absPath) { profile in
                        Button(profile.name) {
                            state.addFirefoxProfile(profile, browserID: firefox.id, isPrivate: false)
                        }
                    }
                }
            }
            if hosts.isEmpty && state.firefoxHost() == nil {
                Text("Add a Chromium-based browser (Chrome, Brave, Edge, Vivaldi, Arc) or Firefox first. Safari and Orion profiles, and Arc Spaces, can't be targeted from outside the browser.")
            }
        }
    }

    private var privateMenu: some View {
        Group {
            ForEach(state.chromiumHosts()) { host in
                if let family = ProfileReader.family(for: host.bundleIdentifier) {
                    Button("\(family.shortName) \(family.privateWord)") {
                        state.addChromePrivate(browserID: host.id)
                    }
                    ForEach(ProfileReader.chromeProfiles(family: family), id: \.directory) { profile in
                        Button("\(family.shortName) · \(profile.name) · \(family.privateWord)") {
                            state.addChromeProfile(profile, browserID: host.id, isPrivate: true)
                        }
                    }
                }
            }
            if let firefox = state.firefoxHost() {
                Button("Firefox Private") {
                    state.addFirefoxPrivate(browserID: firefox.id)
                }
                ForEach(ProfileReader.firefoxProfiles(appURL: firefox.bundleURL), id: \.absPath) { profile in
                    Button("Firefox · \(profile.name) · Private") {
                        state.addFirefoxProfile(profile, browserID: firefox.id, isPrivate: true)
                    }
                }
            }
        }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = String(localized: "Add a browser")
        if panel.runModal() == .OK, let url = panel.url {
            state.addApp(url: url)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var used = false
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.application.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let value = item as? URL {
                    url = value
                } else if let value = item as? NSURL {
                    url = value as URL
                } else {
                    url = nil
                }
                guard let url else { return }
                DispatchQueue.main.async {
                    state.addApp(url: url)
                }
            }
            used = true
        }
        return used
    }
}

private struct BrowserRow: View {
    @EnvironmentObject private var state: AppState
    var row: CatalogRow
    @Binding var draggingID: UUID?
    var move: (UUID, UUID) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 16)
                .contentShape(Rectangle())
                .help("Drag to reorder")
                .onDrag {
                    draggingID = row.id
                    return NSItemProvider(object: BrowsersPane.dragPayload(row.id) as NSString)
                }

            Image(nsImage: BrowserCatalog.icon(for: state.browser(for: row)?.path ?? ""))
                .resizable()
                .interpolation(.high)
                .frame(width: 24, height: 24)
                .opacity(state.isAvailable(row) ? (state.isRunning(row) ? 1 : 0.55) : 0.3)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.title(for: row))
                    .font(.system(size: 13))
                HStack(spacing: 6) {
                    if row.id == state.favourite?.id {
                        Text("Favourite")
                    }
                    if state.isAvailable(row) {
                        Text(state.isRunning(row) ? "Running" : "Not running")
                    } else {
                        Text(state.profileExists(row) ? "Missing" : "Missing profile")
                            .foregroundStyle(.red)
                    }
                    if let subtitle = state.subtitle(for: row) {
                        Text(subtitle)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("In picker", isOn: enabledBinding)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .accessibilityLabel("Show \(state.title(for: row)) in the picker")
                .disabled(!state.isAvailable(row) && !row.enabled)

            Menu {
                rowActions
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Browser actions")
        }
        .onDrop(
            of: [.plainText],
            delegate: ReorderDropDelegate(
                targetID: row.id,
                draggingID: $draggingID,
                move: move
            )
        )
        .contextMenu { rowActions }
    }

    @ViewBuilder
    private var rowActions: some View {
        let index = state.rows.firstIndex(where: { $0.id == row.id }) ?? 0
        if index > 0, let first = state.rows.first {
            Button("Make Favourite") { state.moveRow(id: row.id, to: first.id) }
        }
        Button("Move Up") {
            guard index > 0 else { return }
            state.moveRow(id: row.id, to: state.rows[index - 1].id)
        }
        .disabled(index == 0)
        Button("Move Down") {
            guard index + 1 < state.rows.count else { return }
            state.moveRow(id: row.id, to: state.rows[index + 1].id)
        }
        .disabled(index + 1 >= state.rows.count)
        Divider()
        if let browser = state.browser(for: row),
           FileManager.default.fileExists(atPath: browser.path) {
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: browser.path)])
            }
        }
        Divider()
        Button("Remove", role: .destructive) { state.removeRow(row) }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { row.enabled },
            set: { value in
                guard let index = state.rows.firstIndex(where: { $0.id == row.id }) else { return }
                state.rows[index].enabled = value
                state.save()
            }
        )
    }
}

struct ReorderDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggingID: UUID?
    let move: (UUID, UUID) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.plainText])
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID else { return }
        move(draggingID, targetID)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

extension BrowsersPane {
    static func dragPayload(_ id: UUID) -> String {
        "linkrouter-row:\(id.uuidString)"
    }
}
