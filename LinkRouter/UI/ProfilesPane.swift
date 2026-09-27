import SwiftUI

struct ProfilesPane: View {
    @EnvironmentObject private var state: AppState
    @State private var editing: RouteProfile?
    @State private var selection: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(
                title: "Profiles",
                subtitle: "Personal, work, development: URL patterns that always open in one browser. First match wins, before Rules."
            )

            List {
                ForEach(state.profiles) { profile in
                    ProfileRow(profile: profile, isSelected: selection == profile.id) {
                        selection = profile.id
                        editing = profile
                    }
                    .contextMenu {
                        Button("Edit") {
                            selection = profile.id
                            editing = profile
                        }
                        Button("Delete", role: .destructive) {
                            remove(profile)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: LR.pageInset, bottom: 4, trailing: LR.pageInset))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onMove(perform: state.moveProfiles)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(LR.pageFill)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PaneFooter {
                Button {
                    state.addProfile()
                    editing = state.profiles.last
                    selection = editing?.id
                } label: {
                    Label("Add", systemImage: "plus")
                }
                Button {
                    if let selected = state.profiles.first(where: { $0.id == selection }) {
                        remove(selected)
                    }
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .disabled(selection == nil)
                Spacer()
            }
        }
        .sheet(item: $editing) { profile in
            ProfileEditorSheet(
                profile: profile,
                onSave: { updated in
                    state.updateProfile(updated)
                },
                onDelete: {
                    remove(profile)
                }
            )
            .environmentObject(state)
        }
    }

    private func remove(_ profile: RouteProfile) {
        state.removeProfile(profile)
        if selection == profile.id {
            selection = nil
        }
    }
}

private struct ProfileRow: View {
    @EnvironmentObject private var state: AppState
    var profile: RouteProfile
    var isSelected: Bool
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onEdit) {
                HStack(spacing: 14) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(LR.accent)
                        .frame(width: 28, height: 28)
                        .background(LR.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.leading, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            Toggle("Enabled", isOn: enabledBinding)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .accessibilityLabel("Enable \(profile.name)")
                .tint(LR.accent)
                .padding(.trailing, 14)
        }
        .background(isSelected ? LR.accent.opacity(0.10) : LR.rowFill, in: RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous)
                .strokeBorder(isSelected ? LR.accent.opacity(0.45) : LR.hairline, lineWidth: isSelected ? 1.5 : 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var detail: String {
        let browser: String
        if let id = profile.browserRowID, let row = state.rows.first(where: { $0.id == id }) {
            browser = state.title(for: row)
        } else {
            browser = "No browser"
        }
        return "\(browser) · \(profile.patternSummary)"
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { profile.enabled },
            set: { value in
                var next = profile
                next.enabled = value
                state.updateProfile(next)
            }
        )
    }
}

struct ProfileEditorSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State var profile: RouteProfile
    var onSave: (RouteProfile) -> Void
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(profile.name.isEmpty ? "Profile" : profile.name)
                .font(.system(size: 18, weight: .semibold))

            EditorSection(title: "Name") {
                TextField("Work, Personal, Development…", text: $profile.name)
                    .textFieldStyle(.roundedBorder)
            }

            EditorSection(
                title: "Open in",
                footnote: "Chrome and Firefox rows can be a specific browser profile from the Browsers pane."
            ) {
                ScrollView {
                    BrowserPicker(allowsMultiple: false, selection: browserSelection)
                }
                .frame(maxHeight: 200)
            }

            EditorSection(
                title: "URL patterns",
                footnote: "Host like github.com, or any substring of the URL. First matching profile wins."
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(profile.patterns.enumerated()), id: \.offset) { index, _ in
                        HStack(spacing: 8) {
                            TextField("github.com", text: patternBinding(index))
                                .textFieldStyle(.roundedBorder)
                            Button {
                                profile.patterns.remove(at: index)
                                if profile.patterns.isEmpty { profile.patterns = [""] }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(profile.patterns.count == 1 && profile.filledPatterns.isEmpty)
                        }
                    }
                    Button {
                        profile.patterns.append("")
                    } label: {
                        Label("Add pattern", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }

            HStack {
                if let onDelete {
                    Button("Delete", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    profile.patterns = profile.patterns.map { $0.trimmingCharacters(in: .whitespaces) }
                    if profile.patterns.filter({ !$0.isEmpty }).isEmpty {
                        profile.patterns = [""]
                    }
                    onSave(profile)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(LR.accent)
                .disabled(profile.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520)
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
}
