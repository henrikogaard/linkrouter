import SwiftUI

struct BrowserPicker: View {
    @EnvironmentObject private var state: AppState
    var allowsMultiple: Bool
    var showsOrder = false
    @Binding var selection: [UUID]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(state.enabledRows) { row in
                Button {
                    toggle(row.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(nsImage: BrowserCatalog.icon(for: state.browser(for: row)?.path ?? ""))
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 20, height: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.title(for: row))
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)
                            if let subtitle = state.subtitle(for: row) {
                                Text(subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 8)
                        selectionMark(for: row.id)
                    }
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
            }
            if state.enabledRows.isEmpty {
                Text("Turn on at least one browser in Browsers.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private func selectionMark(for id: UUID) -> some View {
        if showsOrder, let index = selection.firstIndex(of: id) {
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 1))
        } else if selection.contains(id) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 18, height: 18)
        } else {
            Color.clear
                .frame(width: 18, height: 18)
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
