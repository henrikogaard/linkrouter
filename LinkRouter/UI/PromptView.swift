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
    @ObservedObject var countdown: PromptCountdown

    @State private var selected: UUID?
    @State private var hovered: UUID?
    @State private var filter = ""
    @State private var appeared = false

    private var filtering: Bool { items.count > 6 }

    private var visible: [PromptItem] {
        guard filtering, !filter.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: link.isSecure ? "lock.fill" : "globe")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 0) {
                        Text(link.host)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(pathSuffix)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                }
                if let sourceName = link.sourceName {
                    Text("from \(sourceName)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.top, 13)
            .help(link.absoluteString)

            if filtering && !filter.isEmpty {
                Text(filter)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            HStack(alignment: .top, spacing: 4) {
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
            .padding(.horizontal, 14)
            .padding(.top, 10)

            Spacer(minLength: 0)

            Group {
                if let remaining = countdown.remaining, remaining <= 10 {
                    Text("Closes in \(remaining) s")
                        .foregroundStyle(.tertiary)
                } else {
                    Text(" ")
                }
            }
            .font(.system(size: 9, weight: .medium))
            .padding(.bottom, 8)
        }
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                        .padding(0.5)
                }
                .shadow(color: .black.opacity(0.24), radius: 30, y: 14)
        }
        .scaleEffect(appeared ? 1 : 0.94)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            selected = visible.first?.id
            withAnimation(.easeOut(duration: 0.16)) { appeared = true }
        }
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
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? accent.opacity(0.18) : Color.primary.opacity(hovered ? 0.09 : 0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(selected ? accent : accent.opacity(0), lineWidth: 1.5)
                    }
                    .frame(width: 62, height: 62)
                Image(nsImage: item.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 40, height: 40)
                    .opacity(item.running ? 1 : 0.45)
                if index < 9 {
                    Text("\(index + 1)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 13, minHeight: 13)
                        .background(.quaternary, in: Capsule())
                        .padding(.top, 4)
                        .padding(.leading, 5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            VStack(spacing: 0) {
                Text(titleParts.base)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(item.running ? .primary : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(titleParts.qualifier ?? " ")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 74, height: 37, alignment: .top)
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }

    // Theme.swift (LR) is app-target only; this file is shared with the test target.
    private var accent: Color { Color("AccentColor") }

    private var titleParts: (base: String, qualifier: String?) {
        let parts = item.title.components(separatedBy: " · ")
        let qualifier = parts.count > 1 ? parts.dropFirst().joined(separator: " · ") : nil
        return (parts[0], qualifier)
    }

    private var label: String {
        var parts = [item.title]
        if item.running { parts.append(String(localized: "running")) } else { parts.append(String(localized: "not running")) }
        return parts.joined(separator: ", ")
    }
}

private struct CopyCell: View {
    var hovered: Bool

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(hovered ? 0.09 : 0.05))
                    .frame(width: 62, height: 62)
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("⌘C")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 13, minHeight: 13)
                    .padding(.horizontal, 3)
                    .background(.quaternary, in: Capsule())
                    .padding(.top, 4)
                    .padding(.leading, 5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            VStack(spacing: 0) {
                Text("Copy")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(" ")
                    .font(.system(size: 9))
                    .lineLimit(1)
            }
            .frame(width: 74, height: 37, alignment: .top)
        }
        .accessibilityLabel("Copy link")
        .accessibilityAddTraits(.isButton)
    }
}
