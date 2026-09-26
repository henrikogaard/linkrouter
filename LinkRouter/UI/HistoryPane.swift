import AppKit
import SwiftUI

struct HistoryPane: View {
    @EnvironmentObject private var state: AppState
    @State private var filter = ""

    private var visible: [RoutedEntry] {
        guard !filter.isEmpty else { return state.recent }
        return state.recent.filter { entry in
            entry.url.absoluteString.localizedCaseInsensitiveContains(filter)
                || entry.title.localizedCaseInsensitiveContains(filter)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(
                title: "History",
                subtitle: "Every link LinkRouter has routed. Kept to the latest 200."
            )

            TextField("Search links or browsers", text: $filter)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, LR.pageInset)

            if visible.isEmpty {
                Text(filter.isEmpty ? "No links routed yet" : "No matches")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, LR.pageInset)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(visible) { entry in
                            row(entry)
                        }
                    }
                    .padding(.horizontal, LR.pageInset)
                }
            }

            PaneFooter {
                Button("Clear History") { state.clearRecent() }
                    .disabled(state.recent.isEmpty)
            }
        }
        .padding(.bottom, 28)
        .background(LR.pageFill)
    }

    private func row(_ entry: RoutedEntry) -> some View {
        let row = state.rows.first { $0.id == entry.rowID }
        let icon = BrowserCatalog.icon(for: row.flatMap { state.browser(for: $0)?.path } ?? "")
        let host = entry.url.host ?? entry.url.absoluteString
        let path = entry.url.path.isEmpty ? "" : entry.url.path
        return HStack(spacing: 10) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 0) {
                    Text(host)
                    Text(path)
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                Text("→ \(entry.title)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(entry.date.formatted(.relative(presentation: .named)))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(LR.rowFill, in: RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous)
                .strokeBorder(LR.hairline, lineWidth: 1)
        }
        .contextMenu {
            Button("Open again") { state.reopen(entry) }
            Button("Copy link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.url.absoluteString, forType: .string)
            }
            if let row {
                Button("Always open \(host) in \(state.title(for: row))") {
                    state.alwaysOpen(host: host, in: row.id)
                }
            }
        }
    }
}
