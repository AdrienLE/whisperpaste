import AppKit

final class LivePreviewViewController: NSViewController {
    enum State: Equatable { case idle, recording, transcribing, cleaning, error(String) }

    private let statusLabel = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()
    private let editor = MultilineTextEditor(editable: false)
    private let stopButton = NSButton(title: "Transcribe", target: nil, action: nil)
    private let abortButton = NSButton(title: "Abort", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    private let detailsButton = NSButton(title: "Details…", target: nil, action: nil)
    private var recordingIndicatorTimer: Timer?
    private var indicatorStep = 0
    private var lastErrorDetails: String?
    private let actionContainer = NSView()

    private(set) var currentText: String = ""
    private(set) var state: State = .idle
    var onStop: (() -> Void)?
    var onAbort: (() -> Void)?

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 200))

        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = NSColor.secondaryLabelColor
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false

        stopButton.target = self
        stopButton.action = #selector(didTapStop)

        abortButton.target = self
        abortButton.action = #selector(didTapAbort)

        detailsButton.target = self
        detailsButton.action = #selector(showErrorDetails)
        detailsButton.isHidden = true
        detailsButton.bezelStyle = .inline

        copyButton.target = self
        copyButton.action = #selector(copyCurrentText)
        copyButton.bezelStyle = .rounded
        copyButton.isHidden = true

        // Trailing action container to hold Stop/Copy in the same spot
        actionContainer.translatesAutoresizingMaskIntoConstraints = false
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        abortButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        // Stack for recording actions: Abort + Transcribe
        let recordingStack = NSStackView(views: [abortButton, stopButton])
        recordingStack.orientation = .horizontal
        recordingStack.spacing = 6
        recordingStack.alignment = .centerY
        recordingStack.translatesAutoresizingMaskIntoConstraints = false
        recordingStack.identifier = NSUserInterfaceItemIdentifier("recordingStack")
        actionContainer.addSubview(recordingStack)
        actionContainer.addSubview(copyButton)
        NSLayoutConstraint.activate([
            recordingStack.leadingAnchor.constraint(equalTo: actionContainer.leadingAnchor),
            recordingStack.trailingAnchor.constraint(equalTo: actionContainer.trailingAnchor),
            recordingStack.topAnchor.constraint(equalTo: actionContainer.topAnchor),
            recordingStack.bottomAnchor.constraint(equalTo: actionContainer.bottomAnchor),
            copyButton.leadingAnchor.constraint(equalTo: actionContainer.leadingAnchor),
            copyButton.trailingAnchor.constraint(equalTo: actionContainer.trailingAnchor),
            copyButton.topAnchor.constraint(equalTo: actionContainer.topAnchor),
            copyButton.bottomAnchor.constraint(equalTo: actionContainer.bottomAnchor),
            actionContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])

        let topRow = NSStackView(views: [statusLabel, spinner, detailsButton, NSView(), actionContainer])
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
        // Initialize trailing action placement
        if let stack = actionContainer.subviews.first(where: { $0.identifier?.rawValue == "recordingStack" }) {
            stack.isHidden = true
        }
        stopButton.isEnabled = false
        abortButton.isHidden = true
        abortButton.isEnabled = false
    }

    @objc private func didTapStop() { onStop?() }
    @objc private func didTapAbort() { onAbort?() }

    func setState(_ state: State) {
        self.state = state
        switch state {
        case .idle:
            statusLabel.stringValue = "Last result"
            spinner.stopAnimation(nil)
            if let stack = actionContainer.subviews.first(where: { $0.identifier?.rawValue == "recordingStack" }) {
                stack.isHidden = true
            }
            stopButton.isEnabled = false
            abortButton.isHidden = true
            abortButton.isEnabled = false
            detailsButton.isHidden = true
            copyButton.isHidden = (currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            copyButton.isEnabled = !copyButton.isHidden
            stopIndicator()
            refreshEditor()
        case .recording:
            statusLabel.stringValue = "Recording…"
            spinner.startAnimation(nil)
            if let stack = actionContainer.subviews.first(where: { $0.identifier?.rawValue == "recordingStack" }) {
                stack.isHidden = false
            }
            stopButton.isEnabled = true
            abortButton.isHidden = false
            abortButton.isEnabled = true
            copyButton.isHidden = true
            detailsButton.isHidden = true
            // Clear previous text for a fresh session
            currentText = ""
            startIndicator()
            refreshEditor()
        case .transcribing:
            statusLabel.stringValue = "Transcribing…"
            spinner.startAnimation(nil)
            if let stack = actionContainer.subviews.first(where: { $0.identifier?.rawValue == "recordingStack" }) {
                stack.isHidden = true
            }
            stopButton.isEnabled = false
            abortButton.isHidden = true
            abortButton.isEnabled = false
            detailsButton.isHidden = true
            copyButton.isHidden = true
            stopIndicator()
            refreshEditor()
        case .cleaning:
            statusLabel.stringValue = "Cleaning up…"
            spinner.startAnimation(nil)
            if let stack = actionContainer.subviews.first(where: { $0.identifier?.rawValue == "recordingStack" }) {
                stack.isHidden = true
            }
            stopButton.isEnabled = false
            abortButton.isHidden = true
            abortButton.isEnabled = false
            detailsButton.isHidden = true
            copyButton.isHidden = true
            stopIndicator()
            refreshEditor()
        case .error(let msg):
            statusLabel.stringValue = "Error: \(msg)"
            spinner.stopAnimation(nil)
            if let stack = actionContainer.subviews.first(where: { $0.identifier?.rawValue == "recordingStack" }) {
                stack.isHidden = true
            }
            stopButton.isEnabled = false
            abortButton.isHidden = true
            abortButton.isEnabled = false
            detailsButton.isHidden = (lastErrorDetails == nil)
            copyButton.isHidden = (currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            copyButton.isEnabled = !copyButton.isHidden
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
        let framesCount = 8
        recordingIndicatorTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self = self, self.state == .recording else { return }
            self.indicatorStep = (self.indicatorStep + 1) % framesCount
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
        copyButton.isEnabled = !copyButton.isHidden
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
