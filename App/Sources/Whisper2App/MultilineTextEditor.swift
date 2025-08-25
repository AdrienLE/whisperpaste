import AppKit

final class MultilineTextEditor: NSView {
    let scroll = NSScrollView()
    let textView = NSTextView()

    var onChange: ((String) -> Void)?

    init(editable: Bool) {
        super.init(frame: .zero)
        setup(editable: editable)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup(editable: true)
    }

    private func setup(editable: Bool) {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        // Configure text view appearance and behavior
        textView.isEditable = editable
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.automaticQuoteSubstitutionEnabled = false
        textView.automaticDashSubstitutionEnabled = false
        textView.textColor = NSColor.labelColor
        textView.insertionPointColor = NSColor.labelColor
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.controlBackgroundColor
        textView.translatesAutoresizingMaskIntoConstraints = false

        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: NSText.didChangeNotification, object: textView)

        // Configure scroll view
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = textView
        scroll.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func textDidChange(_ note: Notification) { onChange?(textView.string) }

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool {
        window?.makeFirstResponder(textView)
        return true
    }

    var string: String {
        get { textView.string }
        set { textView.string = newValue }
    }
}

