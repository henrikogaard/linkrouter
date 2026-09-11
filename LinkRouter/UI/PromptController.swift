import AppKit
import SwiftUI

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PromptController {
    private var panel: KeyPanel?
    private var hosting: NSHostingView<PromptView>?

    func show(items: [PromptItem], link: IncomingLink, onPick: @escaping (UUID?) -> Void) {
        dismiss()
        guard !items.isEmpty else { return }

        let width = CGFloat(max(items.count, 1)) * 76 + 24
        let height: CGFloat = 148
        var origin = originForPointer(size: NSSize(width: width, height: height), itemCount: items.count)

        let view = PromptView(
            items: items,
            link: link,
            onPick: { [weak self] id in
                self?.dismiss()
                onPick(id)
            },
            onCancel: { [weak self] in
                self?.dismiss()
                onPick(nil)
            }
        )

        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)

        let panel = KeyPanel(
            contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = hosting
        panel.acceptsMouseMovedEvents = true

        self.panel = panel
        self.hosting = hosting

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        origin = clamped(origin, size: panel.frame.size)
        panel.setFrameOrigin(origin)
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        hosting = nil
    }

    private func originForPointer(size: NSSize, itemCount: Int) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let firstCenterX = 12 + 34
        let x = mouse.x - CGFloat(firstCenterX)
        let y = mouse.y - size.height + 40
        return clamped(NSPoint(x: x, y: y), size: size)
    }

    private func clamped(_ origin: NSPoint, size: NSSize) -> NSPoint {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return origin }
        var point = origin
        point.x = min(max(point.x, visible.minX + 8), visible.maxX - size.width - 8)
        point.y = min(max(point.y, visible.minY + 8), visible.maxY - size.height - 8)
        return point
    }
}
