import AppKit

final class MultilineTextEditor: NSView {
    let scroll = NSScrollView()
    let textView: NSTextView
    private let defaultFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    private let isEditableMode: Bool
    var onChange: ((String) -> Void)?
    var autoScrollToEnd: Bool = false
    private var lastContentHeight: CGFloat = 0

    init(editable: Bool) {
        self.isEditableMode = editable
        self.textView = editable ? PasteCapableTextView() : NSTextView()
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.isEditableMode = true
        self.textView = PasteCapableTextView()
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        // Configure text view appearance and behavior
        textView.isEditable = isEditableMode
        textView.isSelectable = true
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        // Sizing/embedding in NSScrollView: use frame-based layout for the documentView
        // and configure the text container to track width for proper layout and visibility.
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        if let container = textView.textContainer {
            container.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            container.widthTracksTextView = true
        }
        if isEditableMode {
            textView.allowsUndo = true
        }

        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: NSText.didChangeNotification, object: textView)

        // Configure scroll view
        scroll.hasVerticalScroller = true
        scroll.documentView = textView
        scroll.translatesAutoresizingMaskIntoConstraints = false

        if isEditableMode {
            // Explicit, adaptive colors for dark/light mode
            textView.drawsBackground = true
            textView.backgroundColor = NSColor.textBackgroundColor
            textView.textColor = NSColor.textColor
            textView.insertionPointColor = NSColor.textColor
            textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            scroll.drawsBackground = false
            scroll.borderType = .bezelBorder
        } else {
            // Read-only look
            textView.font = defaultFont
            textView.drawsBackground = false
            textView.textColor = NSColor.labelColor
            scroll.drawsBackground = false
            scroll.borderType = .noBorder
            textView.textContainerInset = NSSize(width: 4, height: 6)
        }

        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func textDidChange(_ note: Notification) {
        onChange?(textView.string)
        updateContentLayout()
    }

    override var acceptsFirstResponder: Bool { isEditableMode }
    override func becomeFirstResponder() -> Bool {
        guard isEditableMode else { return false }
        window?.makeFirstResponder(textView)
        return true
    }

    override func mouseDown(with event: NSEvent) {
        if isEditableMode {
            window?.makeFirstResponder(textView)
            textView.mouseDown(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }

    var string: String {
        get { textView.string }
        set { textView.string = newValue; updateContentLayout() }
    }

    func setAttributed(_ attributed: NSAttributedString) {
        if isEditableMode {
            // For editable mode, stick to plain string to avoid rich-text editing
            textView.string = attributed.string
        } else {
            textView.textStorage?.setAttributedString(attributed)
        }
        updateContentLayout()
    }

    func scrollToEnd() {
        let tv = textView
        // Defer to next run loop so layout completes before scrolling
        DispatchQueue.main.async {
            if let lm = tv.layoutManager, let tc = tv.textContainer {
                lm.ensureLayout(for: tc)
            }
            tv.scrollToEndOfDocument(nil)
            let len = (tv.string as NSString).length
            tv.scrollRangeToVisible(NSRange(location: len, length: 0))
        }
    }

    private func updateContentLayout() {
        // Keep the text view width in sync with the scroll content width
        // Keep the text view width in sync with the scroll content width
        let viewport = scroll.contentSize
        if textView.frame.size.width != viewport.width {
            textView.setFrameSize(NSSize(width: viewport.width, height: textView.frame.size.height))
        }
        if let container = textView.textContainer {
            let expected = NSSize(width: viewport.width, height: CGFloat.greatestFiniteMagnitude)
            if container.containerSize != expected { container.containerSize = expected }
            if container.widthTracksTextView == false { container.widthTracksTextView = true }
        }
        // Compute required content height and allow the document view to grow beyond the viewport to enable scrolling
        if let lm = textView.layoutManager, let tc = textView.textContainer {
            lm.ensureLayout(for: tc)
            let used = lm.usedRect(for: tc).integral
            let inset = textView.textContainerInset
            let requiredHeight = used.size.height + inset.height * 2
            let newHeight = max(requiredHeight, viewport.height)
            if abs(textView.frame.size.height - newHeight) > 0.5 {
                textView.setFrameSize(NSSize(width: viewport.width, height: newHeight))
            }
            if newHeight > viewport.height && newHeight > lastContentHeight + 2 {
                scroll.flashScrollers()
            }
            lastContentHeight = newHeight
        }
        if autoScrollToEnd { scrollToEnd() }
    }

    override func layout() {
        super.layout()
        updateContentLayout()
    }
}
