import AppKit
import SwiftUI

struct HistoryPane: View {
    @EnvironmentObject private var state: AppState
    @State private var filter = ""
    @State private var selection = Set<RoutedEntry.ID>()
    @State private var confirmClear = false

    private var visible: [RoutedEntry] {
        guard !filter.isEmpty else { return state.recent }
        return state.recent.filter { entry in
            entry.url.absoluteString.localizedCaseInsensitiveContains(filter)
                || entry.title.localizedCaseInsensitiveContains(filter)
        }
    }

    var body: some View {
        Table(visible, selection: $selection) {
            TableColumn("Link") { entry in
                let host = entry.url.host ?? entry.url.absoluteString
                let path = entry.url.path == "/" ? "" : entry.url.path
                HStack(spacing: 0) {
                    Text(host)
                        .foregroundStyle(.primary)
                    Text(path)
                        .foregroundStyle(.tertiary)
                }
                .lineLimit(1)
                .truncationMode(.middle)
                .onTapGesture(count: 2) { state.reopen(entry) }
            }
            .width(min: 220)

            TableColumn("Opened In") { entry in
                let row = state.rows.first { $0.id == entry.rowID }
                HStack(spacing: 7) {
                    Image(nsImage: BrowserCatalog.icon(for: row.flatMap { state.browser(for: $0)?.path } ?? ""))
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(row.map { state.title(for: $0) } ?? entry.title)
                        .lineLimit(1)
                }
            }
            .width(min: 130)

            TableColumn("When") { entry in
                Text(entry.date.formatted(.relative(presentation: .named)))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(110)
        }
        .searchable(text: $filter, prompt: Text("Search links or browsers"))
        .overlay {
            if visible.isEmpty {
                if filter.isEmpty {
                    ContentUnavailableView(
                        "No Links Yet",
                        systemImage: "clock",
                        description: Text("Links LinkRouter routes show up here. The latest 200 are kept.")
                    )
                } else {
                    ContentUnavailableView.search(text: filter)
                }
            }
        }
        .contextMenu(forSelectionType: RoutedEntry.ID.self) { selected in
            if let entry = visible.first(where: { selected.contains($0.id) }) {
                historyActions(for: entry)
            }
        }
        .onTapGesture(count: 2) {
            guard let entry = visible.first(where: { selection.contains($0.id) }) else { return }
            state.reopen(entry)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear History…") { confirmClear = true }
                    .disabled(state.recent.isEmpty)
            }
        }
        .confirmationDialog(
            "Clear History?",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) {
                state.clearRecent()
                selection.removeAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }

    @ViewBuilder
    private func historyActions(for entry: RoutedEntry) -> some View {
        Button("Open Again") { state.reopen(entry) }
        Button("Copy Link") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(entry.url.absoluteString, forType: .string)
        }
        let host = entry.url.host ?? entry.url.absoluteString
        if let row = state.rows.first(where: { $0.id == entry.rowID }) {
            Button("Always Open \(host) in \(state.title(for: row))") {
                state.alwaysOpen(host: host, in: row.id)
            }
        }
    }
}
