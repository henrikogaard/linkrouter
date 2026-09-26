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
    var onPick: (UUID, Bool) -> Void
    var onAlways: (UUID) -> Void
    var onCopy: () -> Void
    var onCancel: () -> Void

    @State private var selected: UUID?
    @State private var hovered: UUID?
    @State private var filter = ""

    private var filtering: Bool { items.count > 6 }

    private var visible: [PromptItem] {
        guard filtering, !filter.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: link.isSecure ? "lock.fill" : "globe")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 0) {
                    Text(link.host)
                        .foregroundStyle(.secondary)
                    Text(pathSuffix)
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .lineLimit(1)
            }
            .padding(.top, 12)
            .help(link.absoluteString)

            if filtering && !filter.isEmpty {
                Text(filter)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .top, spacing: 6) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                    PromptCell(
                        item: item,
                        index: index,
                        selected: selected == item.id || (selected == nil && index == 0),
                        hovered: hovered == item.id
                    )
                    .onHover { inside in
                        hovered = inside ? item.id : (hovered == item.id ? nil : hovered)
                    }
                    .onTapGesture { pick(item.id) }
                    .help(item.title)
                    .contextMenu {
                        Button("Always open \(link.host) in \(item.title)") {
                            onAlways(item.id)
                        }
                    }
                }
                CopyCell(hovered: hovered == copyID)
                    .onHover { inside in
                        hovered = inside ? copyID : (hovered == copyID ? nil : hovered)
                    }
                    .onTapGesture { onCopy() }
                    .help("Copy link")
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
        .onAppear { selected = visible.first?.id }
        .onChange(of: filter) {
            if selected == nil || !visible.contains(where: { $0.id == selected }) {
                selected = visible.first?.id
            }
        }
        .focusable()
        .onKeyPress { press in
            if press.key == .escape {
                if !filter.isEmpty {
                    filter = ""
                } else {
                    onCancel()
                }
                return .handled
            }
            if press.key == .return {
                pick(selected ?? visible.first?.id, keepOpen: press.modifiers.contains(.shift))
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
            if press.key == .delete || press.key == .deleteForward
                || press.characters == "\u{7F}" || press.characters == "\u{8}" {
                if !filter.isEmpty {
                    filter.removeLast()
                    return .handled
                }
                return .ignored
            }
            if press.modifiers.contains(.command), press.characters.lowercased() == "c" {
                onCopy()
                return .handled
            }
            if let value = Int(press.characters), (1...9).contains(value), visible.indices.contains(value - 1) {
                pick(visible[value - 1].id)
                return .handled
            }
            if filtering,
               press.modifiers.isSubset(of: [.shift, .capsLock]),
               press.characters.range(of: #"^[[:print:]]+$"#, options: .regularExpression) != nil {
                filter += press.characters
                return .handled
            }
            return .ignored
        }
        .accessibilityElement(children: .contain)
    }

    private let copyID = UUID()

    private var pathSuffix: String {
        var path = link.url.path
        if let query = link.url.query, !query.isEmpty {
            path += "?" + query
        }
        if path.isEmpty || path == "/" { return "" }
        let budget = max(48 - link.host.count, 8)
        guard path.count > budget else { return path }
        return String(path.prefix(budget - 1)) + "…"
    }

    private func pick(_ id: UUID?, keepOpen: Bool = false) {
        guard let id else { return }
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.option) {
            onAlways(id)
        } else {
            onPick(id, keepOpen || modifiers.contains(.shift))
        }
    }

    private func move(_ delta: Int) {
        guard !visible.isEmpty else { return }
        let current = selected.flatMap { id in visible.firstIndex(where: { $0.id == id }) } ?? 0
        let next = min(max(current + delta, 0), visible.count - 1)
        selected = visible[next].id
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

private struct CopyCell: View {
    var hovered: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(hovered ? Color.primary.opacity(0.12) : Color.primary.opacity(0.04))
                    .frame(width: 64, height: 64)
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text("Copy")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 68, height: 28, alignment: .top)
        }
        .accessibilityLabel("Copy link")
        .accessibilityAddTraits(.isButton)
    }
}
