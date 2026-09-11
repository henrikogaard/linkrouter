import SwiftUI

struct BrowserPicker: View {
    @EnvironmentObject private var state: AppState
    var allowsMultiple: Bool
    @Binding var selection: [UUID]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(state.enabledRows) { row in
                let selected = selection.contains(row.id)
                Button {
                    toggle(row.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(nsImage: BrowserCatalog.icon(for: state.browser(for: row)?.path ?? ""))
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(state.title(for: row))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                            if let subtitle = state.subtitle(for: row) {
                                Text(subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 8)
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(selected ? LR.accent : Color.secondary.opacity(0.45))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selected ? LR.accent.opacity(0.12) : LR.rowFill)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(selected ? LR.accent.opacity(0.4) : LR.hairline, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
            if state.enabledRows.isEmpty {
                Text("Turn on at least one browser in Browsers.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
    }

    private func toggle(_ id: UUID) {
        if allowsMultiple {
            if let index = selection.firstIndex(of: id) {
                selection.remove(at: index)
            } else {
                selection.append(id)
            }
        } else {
            selection = [id]
        }
    }
}

struct EditorSection<Content: View>: View {
    var title: String
    var footnote: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            content
            if let footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
