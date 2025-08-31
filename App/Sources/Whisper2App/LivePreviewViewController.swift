import AppKit

final class LivePreviewViewController: NSViewController {
    enum State: Equatable { case idle, recording, transcribing, cleaning, error(String) }

    private let statusLabel = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()
    private let editor = MultilineTextEditor(editable: false)
    private let stopButton = NSButton(title: "Stop", target: nil, action: nil)
    private var recordingIndicatorTimer: Timer?
    private var indicatorStep = 0

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

        let topRow = NSStackView(views: [statusLabel, spinner, NSView(), stopButton])
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 8
        topRow.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [topRow, editor])
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
        // Initialize visuals without overriding externally-set state
        statusLabel.stringValue = (state == .idle) ? "Idle" : statusLabel.stringValue
        if currentText.isEmpty { editor.string = "Speak to see live preview…" } else { editor.string = currentText }
    }

    @objc private func didTapStop() { onStop?() }

    func setState(_ state: State) {
        self.state = state
        switch state {
        case .idle:
            statusLabel.stringValue = "Idle"
            spinner.stopAnimation(nil)
            stopButton.isHidden = true
            stopIndicator()
            refreshEditor()
        case .recording:
            statusLabel.stringValue = "Recording…"
            spinner.startAnimation(nil)
            stopButton.isHidden = false
            startIndicator()
            refreshEditor()
        case .transcribing:
            statusLabel.stringValue = "Transcribing…"
            spinner.startAnimation(nil)
            stopButton.isHidden = true
            stopIndicator()
            refreshEditor()
        case .cleaning:
            statusLabel.stringValue = "Cleaning up…"
            spinner.startAnimation(nil)
            stopButton.isHidden = true
            stopIndicator()
            refreshEditor()
        case .error(let msg):
            statusLabel.stringValue = "Error: \(msg)"
            spinner.stopAnimation(nil)
            stopButton.isHidden = true
            stopIndicator()
            refreshEditor()
        }
    }

    func update(text: String) {
        currentText = text
        refreshEditor()
    }

    func reset() {
        currentText = ""
        refreshEditor()
    }

    private func refreshEditor() {
        let base = currentText.isEmpty ? "Speak to see live preview…" : currentText
        if state == .recording && !currentText.isEmpty {
            editor.string = base + indicatorString()
        } else {
            editor.string = base
        }
        editor.scrollToEnd()
    }

    private func startIndicator() {
        stopIndicator()
        indicatorStep = 0
        recordingIndicatorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.state == .recording else { return }
            self.indicatorStep = (self.indicatorStep + 1) % 4
            self.refreshEditor()
        }
        RunLoop.main.add(recordingIndicatorTimer!, forMode: .common)
    }

    private func stopIndicator() {
        recordingIndicatorTimer?.invalidate()
        recordingIndicatorTimer = nil
    }

    private func indicatorString() -> String {
        let dots = [" ∘", " ∘·", " ∘··", " ∘···"]
        return dots[indicatorStep]
    }
}
