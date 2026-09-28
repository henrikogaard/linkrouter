import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct BrowsersPane: View {
    @EnvironmentObject private var state: AppState
    @State private var selection: CatalogRow.ID?
    @State private var draggingID: CatalogRow.ID?
    @State private var dropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(
                title: "Browsers",
                subtitle: "First in the list is the favourite. A click on the picker lands there. Drag the handle to reorder."
            )
            DefaultBanner()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(state.rows) { row in
                        BrowserRow(
                            row: row,
                            isSelected: selection == row.id,
                            isDragging: draggingID == row.id,
                            onSelect: { selection = row.id },
                            onDragStart: {
                                draggingID = row.id
                                return NSItemProvider(object: Self.dragPayload(row.id) as NSString)
                            }
                        )
                        .onDrop(
                            of: [.plainText],
                            delegate: BrowserReorderDrop(
                                targetID: row.id,
                                draggingID: $draggingID,
                                move: { from, to in
                                    withAnimation(.snappy(duration: 0.18)) {
                                        state.moveRow(id: from, to: to)
                                    }
                                }
                            )
                        )
                    }
                }
                .padding(.horizontal, LR.pageInset)
                .padding(.bottom, 16)
                .animation(.snappy(duration: 0.18), value: state.rows.map(\.id))
            }
            .onDrop(of: [.application], isTargeted: $dropTargeted, perform: handleDrop)
            .overlay {
                if dropTargeted {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(LR.accent, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .padding(12)
                }
            }
        }
        .background(LR.pageFill)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }

    static func dragPayload(_ id: CatalogRow.ID) -> String {
        "linkrouter-row:\(id.uuidString)"
    }

    private var footer: some View {
        PaneFooter {
            Button(action: pickApp) {
                Label("Add", systemImage: "plus")
            }
            .help("Add a browser from disk")

            Menu {
                profileMenu
            } label: {
                Label("Profile", systemImage: "person.crop.circle")
            }

            Menu {
                privateMenu
            } label: {
                Label("Private", systemImage: "eye.slash")
            }

            Button {
                if let id = selection, let row = state.rows.first(where: { $0.id == id }) {
                    state.removeRow(row)
                    selection = nil
                }
            } label: {
                Label("Remove", systemImage: "minus")
            }
            .disabled(selection == nil)

            Spacer()

            Button("Refresh", action: state.refreshDiscovered)
        }
    }

    @ViewBuilder
    private var profileMenu: some View {
        let hosts = state.chromiumHosts()
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

    @ViewBuilder
    private var privateMenu: some View {
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

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Add a browser"
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
    var isSelected: Bool
    var isDragging: Bool
    var onSelect: () -> Void
    var onDragStart: () -> NSItemProvider

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            handle
                .onDrag(onDragStart)
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    icon
                    titles
                    Spacer(minLength: 8)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityLabel(label)
            Toggle("In picker", isOn: enabledBinding)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .accessibilityLabel("Show \(state.title(for: row)) in the picker")
                .tint(LR.accent)
                .disabled(!state.isAvailable(row))
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .padding(.vertical, 10)
        .background(fill, in: RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous)
                .strokeBorder(stroke, lineWidth: isSelected ? 1.5 : 1)
        }
        .opacity(isDragging ? 0.42 : 1)
        .contentShape(RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous))
        .onHover { hovering = $0 }
        .accessibilityElement(children: .contain)
    }

    private var handle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(hovering || isSelected ? Color.secondary : Color.primary.opacity(0.35))
            .frame(width: 18, height: 36)
            .contentShape(Rectangle())
            .help("Drag to reorder")
            .onHover { inside in
                if inside { NSCursor.openHand.push() } else { NSCursor.pop() }
            }
            .accessibilityLabel("Reorder \(state.title(for: row))")
    }

    private var icon: some View {
        Image(nsImage: BrowserCatalog.icon(for: state.browser(for: row)?.path ?? ""))
            .resizable()
            .interpolation(.high)
            .frame(width: 36, height: 36)
            .opacity(state.isAvailable(row) ? (state.isRunning(row) ? 1 : 0.42) : 0.3)
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(state.title(for: row))
                .font(.system(size: 14, weight: .medium))
            HStack(spacing: 8) {
                if row.id == state.favourite?.id {
                    Text("Favourite")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(LR.accent)
                }
                if state.isAvailable(row) {
                    Text(state.isRunning(row) ? "Running" : "Not running")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text(state.profileExists(row) ? "Missing" : "Missing profile")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
                if let subtitle = state.subtitle(for: row) {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var fill: Color {
        if isSelected { return LR.accent.opacity(0.10) }
        if hovering { return LR.accent.opacity(0.07) }
        return LR.rowFill
    }

    private var stroke: Color {
        isSelected ? LR.accent.opacity(0.45) : LR.hairline
    }

    private var label: String {
        if !state.isAvailable(row) {
            return state.title(for: row) + String(localized: ", missing")
        }
        return state.title(for: row) + (state.isRunning(row) ? String(localized: ", running") : String(localized: ", not running"))
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { row.enabled },
            set: { value in
                if let index = state.rows.firstIndex(where: { $0.id == row.id }) {
                    state.rows[index].enabled = value
                    state.save()
                }
            }
        )
    }
}

private struct BrowserReorderDrop: DropDelegate {
    let targetID: CatalogRow.ID
    @Binding var draggingID: CatalogRow.ID?
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
