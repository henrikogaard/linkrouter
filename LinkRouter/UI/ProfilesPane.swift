import AppKit
import SwiftUI

struct ProfilesPane: View {
    @EnvironmentObject private var state: AppState
    @State private var editing: RouteProfile?
    @State private var draggingID: UUID?

    var body: some View {
        Form {
            Section {
                if state.profiles.isEmpty {
                    Text("No profiles yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(state.profiles) { profile in
                    ProfileRow(
                        profile: profile,
                        draggingID: $draggingID,
                        move: state.moveProfile,
                        onEdit: { editing = profile }
                    )
                }
            } footer: {
                Text("A profile sends matching links straight to one browser, before any rule runs. The first match wins.")
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    state.addProfile()
                    editing = state.profiles.last
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editing) { profile in
            ProfileEditorSheet(
                profile: profile,
                onSave: state.updateProfile,
                onDelete: { state.removeProfile(profile) }
            )
            .environmentObject(state)
        }
    }
}

private struct ProfileRow: View {
    @EnvironmentObject private var state: AppState
    var profile: RouteProfile
    @Binding var draggingID: UUID?
    var move: (UUID, UUID) -> Void
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 16)
                .contentShape(Rectangle())
                .help("Drag to reorder")
                .onDrag {
                    draggingID = profile.id
                    return NSItemProvider(object: BrowsersPane.dragPayload(profile.id) as NSString)
                }

            browserIcon
                .frame(width: 24, height: 24)

            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 13))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("Enabled", isOn: enabledBinding)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .accessibilityLabel("Enable \(profile.name)")

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
            .accessibilityLabel("Profile actions")
        }
        .onDrop(
            of: [.plainText],
            delegate: ReorderDropDelegate(
                targetID: profile.id,
                draggingID: $draggingID,
                move: move
            )
        )
        .contextMenu { rowActions }
    }

    private var browserIcon: some View {
        Group {
            if let id = profile.browserRowID,
               let row = state.rows.first(where: { $0.id == id }),
               let browser = state.browser(for: row) {
                Image(nsImage: BrowserCatalog.icon(for: browser.path))
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "questionmark.app.dashed")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var subtitle: String {
        let browser: String
        if let id = profile.browserRowID, let row = state.rows.first(where: { $0.id == id }) {
            browser = state.title(for: row)
        } else {
            browser = String(localized: "No browser")
        }
        return String(localized: "\(profile.patternSummary) → \(browser)")
    }

    @ViewBuilder
    private var rowActions: some View {
        Button("Edit…", action: onEdit)
        let index = state.profiles.firstIndex(where: { $0.id == profile.id }) ?? 0
        Button("Move Up") {
            guard index > 0 else { return }
            state.moveProfile(id: profile.id, to: state.profiles[index - 1].id)
        }
        .disabled(index == 0)
        Button("Move Down") {
            guard index + 1 < state.profiles.count else { return }
            state.moveProfile(id: profile.id, to: state.profiles[index + 1].id)
        }
        .disabled(index + 1 >= state.profiles.count)
        Divider()
        Button("Delete", role: .destructive) {
            state.removeProfile(profile)
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { profile.enabled },
            set: { value in
                var updated = profile
                updated.enabled = value
                state.updateProfile(updated)
            }
        )
    }
}

struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var profile: RouteProfile
    var onSave: (RouteProfile) -> Void
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $profile.name, prompt: Text("Work, Personal, Development…"))
                }

                Section {
                    BrowserPicker(allowsMultiple: false, selection: browserSelection)
                } header: {
                    Text("Open In")
                } footer: {
                    Text("Chrome and Firefox rows can be a specific browser profile from the Browsers pane.")
                }

                Section {
                    ForEach(Array(profile.patterns.enumerated()), id: \.offset) { index, _ in
                        HStack {
                            TextField("Web address", text: patternBinding(index), prompt: Text("github.com"))
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                profile.patterns.remove(at: index)
                                if profile.patterns.isEmpty { profile.patterns = [""] }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .disabled(profile.patterns.count == 1 && profile.filledPatterns.isEmpty)
                        }
                    }
                    Button {
                        profile.patterns.append("")
                    } label: {
                        Label("Add Pattern", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                } header: {
                    Text("URL Patterns")
                } footer: {
                    Text("Host like github.com, or any substring of the URL. First matching profile wins.")
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            editorBar
        }
        .frame(width: 520, height: 480)
    }

    private var editorBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                if let onDelete {
                    Button("Delete…", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .foregroundStyle(.red)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(LR.accent)
                    .disabled(profile.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
    }

    private var browserSelection: Binding<[UUID]> {
        Binding(
            get: { profile.browserRowID.map { [$0] } ?? [] },
            set: { profile.browserRowID = $0.first }
        )
    }

    private func patternBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { profile.patterns.indices.contains(index) ? profile.patterns[index] : "" },
            set: { value in
                guard profile.patterns.indices.contains(index) else { return }
                profile.patterns[index] = value
            }
        )
    }

    private func save() {
        profile.patterns = profile.patterns.map { $0.trimmingCharacters(in: .whitespaces) }
        if profile.patterns.filter({ !$0.isEmpty }).isEmpty {
            profile.patterns = [""]
        }
        onSave(profile)
        dismiss()
    }
}
