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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 0) {
                        Text(link.host)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(pathSuffix)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                }
                if let sourceName = link.sourceName {
                    Text("from \(sourceName)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.top, 14)
            .padding(.horizontal, 18)
            .help(link.absoluteString)

            if filtering && !filter.isEmpty {
                Text(filter)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
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
            .padding(.horizontal, 14)
            .padding(.top, 12)

            Spacer(minLength: 0)

            Group {
                if let remaining = countdown.remaining, remaining <= 10 {
                    Text("Closes in \(remaining) s")
                        .foregroundStyle(.tertiary)
                } else {
                    HStack(spacing: 10) {
                        KeyHint(key: "↩", label: "Open")
                        KeyHint(key: "⇧↩", label: "Keep open")
                        KeyHint(key: "⌥", label: "Always")
                        KeyHint(key: "esc", label: "Cancel")
                    }
                }
            }
            .font(.system(size: 9, weight: .medium))
            .padding(.bottom, 9)
        }
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.28), lineWidth: 0.5)
                        .padding(0.5)
                }
        }
        .scaleEffect(appeared ? 1 : 0.92)
        .offset(y: appeared ? 0 : 6)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            selected = visible.first?.id
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { appeared = true }
        }
        .onChange(of: filter) {
            if selected == nil || !visible.contains(where: { $0.id == selected }) {
                selected = visible.first?.id
            }
        }
        .focusable()
        .focusEffectDisabled()
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
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(selected ? accent.opacity(0.20) : Color.primary.opacity(hovered ? 0.10 : 0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .strokeBorder(selected ? accent : accent.opacity(0), lineWidth: 2)
                    }
                    .frame(width: 68, height: 68)
                Image(nsImage: item.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 46, height: 46)
                    .opacity(item.running ? 1 : 0.55)
                    .saturation(item.running ? 1 : 0.6)
                if item.running {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.2))
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
                if index < 9 {
                    KeyBadge(text: "\(index + 1)")
                }
            }
            .frame(width: 68, height: 68)
            .scaleEffect(hovered && !selected ? 1.04 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovered)
            VStack(spacing: 0) {
                Text(titleParts.base)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(item.running ? .primary : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(titleParts.qualifier ?? " ")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 80, height: 40, alignment: .top)
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
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.primary.opacity(hovered ? 0.10 : 0.05))
                    .frame(width: 68, height: 68)
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)
                KeyBadge(text: "⌘C")
            }
            .frame(width: 68, height: 68)
            .scaleEffect(hovered ? 1.04 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovered)
            VStack(spacing: 0) {
                Text("Copy")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(" ")
                    .font(.system(size: 9.5))
                    .lineLimit(1)
            }
            .frame(width: 80, height: 40, alignment: .top)
        }
        .accessibilityLabel("Copy link")
        .accessibilityAddTraits(.isButton)
    }
}

private struct KeyBadge: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(minWidth: 15, minHeight: 15)
            .padding(.horizontal, 3)
            .background(.quaternary, in: Capsule())
            .padding(.top, 5)
            .padding(.leading, 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct KeyHint: View {
    var key: String
    var label: LocalizedStringKey

    var body: some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .frame(minHeight: 13)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 3.5, style: .continuous))
            Text(label)
                .foregroundStyle(.tertiary)
        }
        .fixedSize()
    }
}
