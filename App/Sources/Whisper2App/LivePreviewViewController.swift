import AppKit

final class LivePreviewViewController: NSViewController {
    enum State: Equatable { case idle, recording, transcribing, cleaning, error(String) }

    private let statusLabel = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()
    private let scroll = NSScrollView()
    private let textView = NSTextView()
    private let stopButton = NSButton(title: "Stop", target: nil, action: nil)

    private(set) var currentText: String = ""
    private(set) var state: State = .idle
    var onStop: (() -> Void)?

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 200))

        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = NSColor.secondaryLabelColor
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false

        stopButton.target = self
        stopButton.action = #selector(didTapStop)

        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor

        let topRow = NSStackView(views: [statusLabel, spinner, NSView(), stopButton])
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 8
        topRow.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [topRow, scroll])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])

        self.view = container
        setState(.idle)
        reset()
    }

    @objc private func didTapStop() { onStop?() }

    func setState(_ state: State) {
        self.state = state
        switch state {
        case .idle:
            statusLabel.stringValue = "Idle"
            spinner.stopAnimation(nil)
            stopButton.isHidden = true
        case .recording:
            statusLabel.stringValue = "Recording…"
            spinner.startAnimation(nil)
            stopButton.isHidden = false
        case .transcribing:
            statusLabel.stringValue = "Transcribing with OpenAI…"
            spinner.startAnimation(nil)
            stopButton.isHidden = true
        case .cleaning:
            statusLabel.stringValue = "Cleaning up text…"
            spinner.startAnimation(nil)
            stopButton.isHidden = true
        case .error(let msg):
            statusLabel.stringValue = "Error: \(msg)"
            spinner.stopAnimation(nil)
            stopButton.isHidden = true
        }
    }

    func update(text: String) {
        currentText = text
        textView.string = text.isEmpty ? "Speak to see live preview…" : text
    }

    func reset() {
        currentText = ""
        textView.string = "Speak to see live preview…"
    }
}
