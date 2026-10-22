import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ShortcutRecorder: View {
    var combo: KeyCombo?
    var onChange: (KeyCombo?) -> Bool

    var body: some View {
        HStack(spacing: 4) {
            ShortcutRecorderInput(combo: combo, onChange: onChange)
                .frame(maxWidth: .infinity)
            if combo != nil {
                Button {
                    _ = onChange(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 14, height: 16)
                .focusEffectDisabled()
                .accessibilityLabel("Clear Shortcut")
            }
        }
        .padding(.horizontal, 8)
        .frame(width: 130, height: 26)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .focusEffectDisabled()
    }

    final class Coordinator {
        var onChange: (KeyCombo?) -> Bool
        init(onChange: @escaping (KeyCombo?) -> Bool) { self.onChange = onChange }
    }
}

private struct ShortcutRecorderInput: NSViewRepresentable {
    var combo: KeyCombo?
    var onChange: (KeyCombo?) -> Bool

    func makeCoordinator() -> ShortcutRecorder.Coordinator {
        ShortcutRecorder.Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.coordinator = context.coordinator
        button.combo = combo
        button.refreshTitle()
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        context.coordinator.onChange = onChange
        button.coordinator = context.coordinator
        button.combo = combo
        button.refreshTitle()
    }
}

final class ShortcutRecorderButton: NSButton {
    var combo: KeyCombo?
    weak var coordinator: ShortcutRecorder.Coordinator?
    private var recording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .regularSquare
        isBordered = false
        setButtonType(.momentaryPushIn)
        alignment = .center
        focusRingType = .none
        font = .systemFont(ofSize: 11)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        recording = true
        refreshTitle()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == UInt16(kVK_Escape) {
            recording = false
            refreshTitle()
            return
        }
        if event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete) {
            if coordinator?.onChange(nil) == true { combo = nil }
            recording = false
            refreshTitle()
            return
        }
        let modifiers = KeyCombo.carbonModifiers(for: event.modifierFlags)
        let candidate = KeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers)
        guard candidate.hasRequiredModifier else { NSSound.beep(); return }
        if coordinator?.onChange(candidate) == true {
            combo = candidate
            recording = false
            refreshTitle()
        } else {
            NSSound.beep()
        }
    }

    func refreshTitle() {
        let text = recording
            ? String(localized: "Type Shortcut…")
            : (combo?.displayString ?? String(localized: "Record Shortcut"))
        let color = (recording || combo == nil) ? NSColor.secondaryLabelColor : .labelColor
        attributedTitle = NSAttributedString(
            string: text,
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: color]
        )
    }
}
