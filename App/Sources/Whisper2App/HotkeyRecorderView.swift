import AppKit

final class HotkeyRecorderView: NSView {
    private let recordButton = NSButton(title: "Record", target: nil, action: nil)
    private let displayField = NSTextField(labelWithString: "")
    private var isRecording = false

    var hotkeyString: String = "" { didSet { updateDisplay() } }
    var onChange: ((String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var acceptsFirstResponder: Bool { true }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        recordButton.target = self
        recordButton.action = #selector(toggleRecording)
        let stack = NSStackView(views: [displayField, recordButton])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        displayField.stringValue = "Not set"
        displayField.lineBreakMode = .byTruncatingTail
    }

    private func updateDisplay() {
        displayField.stringValue = hotkeyString.isEmpty ? "Not set" : hotkeyString
    }

    @objc private func toggleRecording() {
        isRecording.toggle()
        recordButton.title = isRecording ? "Listening…" : "Record"
        if isRecording { window?.makeFirstResponder(self) }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        // Capture a single key with modifiers
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let parts = [
            flags.contains(.control) ? "ctrl" : nil,
            flags.contains(.option) ? "alt" : nil,
            flags.contains(.shift) ? "shift" : nil,
            flags.contains(.command) ? "cmd" : nil,
            keyName(from: event)
        ].compactMap { $0 }
        let combo = parts.joined(separator: "+")
        hotkeyString = combo
        onChange?(combo)
        isRecording = false
        recordButton.title = "Record"
    }

    private func keyName(from event: NSEvent) -> String {
        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            let scalar = chars.uppercased()
            switch scalar {
            case " ": return "space"
            default: return scalar
            }
        }
        return "key"
    }
}
