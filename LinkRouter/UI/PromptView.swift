import AppKit
import SwiftUI

struct PromptItem: Identifiable {
    var id: UUID
    var title: String
    var running: Bool
    var icon: NSImage
}

struct PromptView: View {
    var items: [PromptItem]
    var link: IncomingLink
    var onPick: (UUID) -> Void
    var onCancel: () -> Void

    @State private var selected: UUID?
    @State private var hovered: UUID?

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: link.isSecure ? "lock.fill" : "globe")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(link.host)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.top, 12)

            HStack(alignment: .top, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    PromptCell(
                        item: item,
                        index: index,
                        selected: selected == item.id || (selected == nil && index == 0),
                        hovered: hovered == item.id
                    )
                    .onHover { inside in
                        hovered = inside ? item.id : (hovered == item.id ? nil : hovered)
                    }
                    .onTapGesture { onPick(item.id) }
                    .help(item.title)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.28), radius: 24, y: 10)
        }
        .onAppear { selected = items.first?.id }
        .focusable()
        .onKeyPress { press in
            if press.key == .escape {
                onCancel()
                return .handled
            }
            if press.key == .return {
                if let selected { onPick(selected) }
                else if let first = items.first { onPick(first.id) }
                return .handled
            }
            if press.key == .leftArrow {
                move(-1)
                return .handled
            }
            if press.key == .rightArrow {
                move(1)
                return .handled
            }
            if let value = Int(press.characters), (1...9).contains(value), items.indices.contains(value - 1) {
                onPick(items[value - 1].id)
                return .handled
            }
            return .ignored
        }
        .accessibilityElement(children: .contain)
    }

    private func move(_ delta: Int) {
        guard !items.isEmpty else { return }
        let current = selected.flatMap { id in items.firstIndex(where: { $0.id == id }) } ?? 0
        let next = min(max(current + delta, 0), items.count - 1)
        selected = items[next].id
    }
}

private struct PromptCell: View {
    var item: PromptItem
    var index: Int
    var selected: Bool
    var hovered: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected || hovered ? Color.primary.opacity(0.12) : Color.primary.opacity(0.04))
                    .frame(width: 64, height: 64)
                Image(nsImage: item.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 40, height: 40)
                    .opacity(item.running ? 1 : 0.45)
            }
            Text(item.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(item.running ? .primary : .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 68, height: 28, alignment: .top)
            if index < 9 {
                Text("\(index + 1)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }

    private var label: String {
        var parts = [item.title]
        if item.running { parts.append("running") } else { parts.append("not running") }
        return parts.joined(separator: ", ")
    }
}
