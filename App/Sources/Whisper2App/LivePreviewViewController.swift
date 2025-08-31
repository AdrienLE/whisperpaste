import AppKit

final class LivePreviewViewController: NSViewController {
    enum State: Equatable { case idle, recording, transcribing, cleaning, error(String) }

    private let statusLabel = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()
    private let editor = MultilineTextEditor(editable: false)
    private let stopButton = NSButton(title: "Stop", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    private let detailsButton = NSButton(title: "Details…", target: nil, action: nil)
    private var recordingIndicatorTimer: Timer?
    private var indicatorStep = 0 // 0..2 cycling
    private var lastErrorDetails: String?

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

        detailsButton.target = self
        detailsButton.action = #selector(showErrorDetails)
        detailsButton.isHidden = true
        detailsButton.bezelStyle = .inline

        copyButton.target = self
        copyButton.action = #selector(copyCurrentText)
        copyButton.bezelStyle = .inline
        copyButton.isHidden = true

        let topRow = NSStackView(views: [statusLabel, spinner, detailsButton, NSView(), copyButton, stopButton])
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
        editor.autoScrollToEnd = true
        // Keep Stop button space reserved to avoid layout jumps
        stopButton.isBordered = true
        stopButton.alphaValue = 0.0
        stopButton.isEnabled = false
    }

    @objc private func didTapStop() { onStop?() }

    func setState(_ state: State) {
        self.state = state
        switch state {
        case .idle:
            statusLabel.stringValue = "Last result"
            spinner.stopAnimation(nil)
            stopButton.alphaValue = 0.0
            stopButton.isEnabled = false
            detailsButton.isHidden = true
            copyButton.isHidden = (currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            stopIndicator()
            refreshEditor()
        case .recording:
            statusLabel.stringValue = "Recording…"
            spinner.startAnimation(nil)
            stopButton.alphaValue = 1.0
            stopButton.isEnabled = true
            copyButton.isHidden = true
            detailsButton.isHidden = true
            // Clear previous text for a fresh session
            currentText = ""
            startIndicator()
            refreshEditor()
        case .transcribing:
            statusLabel.stringValue = "Transcribing…"
            spinner.startAnimation(nil)
            stopButton.alphaValue = 0.0
            stopButton.isEnabled = false
            detailsButton.isHidden = true
            copyButton.isHidden = true
            stopIndicator()
            refreshEditor()
        case .cleaning:
            statusLabel.stringValue = "Cleaning up…"
            spinner.startAnimation(nil)
            stopButton.alphaValue = 0.0
            stopButton.isEnabled = false
            detailsButton.isHidden = true
            copyButton.isHidden = true
            stopIndicator()
            refreshEditor()
        case .error(let msg):
            statusLabel.stringValue = "Error: \(msg)"
            spinner.stopAnimation(nil)
            stopButton.alphaValue = 0.0
            stopButton.isEnabled = false
            detailsButton.isHidden = (lastErrorDetails == nil)
            copyButton.isHidden = (currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        let baseText: String = {
            switch state {
            case .recording:
                // No placeholder during recording; show only text + indicator
                return currentText
            default:
                return currentText.isEmpty ? "Speak to see live preview…" : currentText
            }
        }()
        if state == .recording && !currentText.isEmpty {
            let baseAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.labelColor,
                .font: editor.textView.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            ]
            let attr = NSMutableAttributedString(string: baseText, attributes: baseAttrs)
            let dots = indicatorAttributed(font: (baseAttrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 13))
            attr.append(NSAttributedString(string: " "))
            attr.append(dots)
            editor.setAttributed(attr)
        } else if state == .recording && currentText.isEmpty {
            // Only show animated dots (fixed width) during recording when no text yet
            let font = editor.textView.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            editor.setAttributed(indicatorAttributed(font: font))
        } else {
            editor.string = baseText
        }
        editor.scrollToEnd()
    }

    private func startIndicator() {
        stopIndicator()
        indicatorStep = 0
        recordingIndicatorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.state == .recording else { return }
            self.indicatorStep = (self.indicatorStep + 1) % 3
            self.refreshEditor()
        }
        RunLoop.main.add(recordingIndicatorTimer!, forMode: .common)
    }

    private func stopIndicator() {
        recordingIndicatorTimer?.invalidate()
        recordingIndicatorTimer = nil
    }

    private func indicatorAttributed(font: NSFont) -> NSAttributedString {
        // Fixed-width braille spinner frames
        let frames = ["⣷", "⣯", "⣟", "⡿", "⢿", "⣻", "⣽", "⣾"]
        let idx = max(0, indicatorStep % frames.count)
        let frame = frames[idx]
        return NSAttributedString(string: frame, attributes: [
            .foregroundColor: NSColor.controlAccentColor,
            .font: font
        ])
    }

    @objc private func showErrorDetails() {
        guard let details = lastErrorDetails, !details.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Transcription Pipeline Error"
        alert.informativeText = details
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func setErrorDetails(_ details: String?) {
        lastErrorDetails = details
        statusLabel.toolTip = details
        if case .error = state { detailsButton.isHidden = (details == nil) }
    }

    func showFinalText(_ text: String) {
        currentText = text
        copyButton.isHidden = currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        refreshEditor()
    }

    @objc private func copyCurrentText() {
        let textToCopy = currentText
        guard !textToCopy.isEmpty else { NSSound.beep(); return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(textToCopy, forType: .string)
    }
}
