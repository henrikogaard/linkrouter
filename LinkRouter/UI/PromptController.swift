import AppKit
import SwiftUI

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PromptCountdown: ObservableObject {
    @Published var remaining: Int?
}

@MainActor
final class PromptController {
    private var panel: KeyPanel?
    private var hosting: NSHostingView<PromptView>?
    private var timeoutTimer: Timer?
    let countdown = PromptCountdown()

    var isVisible: Bool { panel != nil }

    func show(
        items: [PromptItem],
        link: IncomingLink,
        timeout: Int = 0,
        onPick: @escaping (UUID?, Bool) -> Void,
        onAlways: @escaping (UUID) -> Void,
        onTimeout: @escaping () -> Void = {}
    ) {
        dismiss()
        guard !items.isEmpty else { return }

        let width = CGFloat(max(items.count, 1) + 1) * 76 + 24
        let height: CGFloat = items.count > 6 ? 174 : 160
        var origin = originForPointer(size: NSSize(width: width, height: height), itemCount: items.count)

        let view = PromptView(
            items: items,
            link: link,
            onPick: { [weak self] id, keepOpen in
                if !keepOpen { self?.dismiss() }
                onPick(id, keepOpen)
            },
            onAlways: { [weak self] id in
                self?.dismiss()
                onAlways(id)
            },
            onCopy: { [weak self] in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(link.url.absoluteString, forType: .string)
                self?.dismiss()
                onPick(nil, false)
            },
            onCancel: { [weak self] in
                self?.dismiss()
                onPick(nil, false)
            },
            countdown: countdown
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

        if timeout > 0 {
            countdown.remaining = timeout
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    guard let remaining = self.countdown.remaining, remaining > 1 else {
                        self.dismiss()
                        onTimeout()
                        return
                    }
                    self.countdown.remaining = remaining - 1
                }
            }
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        origin = clamped(origin, size: panel.frame.size)
        panel.setFrameOrigin(origin)
    }

    func dismiss() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        countdown.remaining = nil
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
