import AppKit

final class MultilineTextEditor: NSView {
    let scroll = NSScrollView()
    let textView = NSTextView()
    private let defaultFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

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
        textView.font = defaultFont
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textColor = NSColor.textColor
        textView.insertionPointColor = NSColor.textColor
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.typingAttributes = [
            .foregroundColor: NSColor.textColor,
            .font: defaultFont
        ]

        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: NSText.didChangeNotification, object: textView)

        // Configure scroll view
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = NSColor.textBackgroundColor
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

    @objc private func textDidChange(_ note: Notification) {
        applyDefaultAttributes()
        onChange?(textView.string)
    }

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool {
        window?.makeFirstResponder(textView)
        return true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(textView)
        textView.mouseDown(with: event)
    }

    var string: String {
        get { textView.string }
        set {
            textView.string = newValue
            applyDefaultAttributes()
        }
    }

    private func applyDefaultAttributes() {
        let length = (textView.string as NSString).length
        guard length > 0, let storage = textView.textStorage else { return }
        storage.beginEditing()
        storage.setAttributes([
            .foregroundColor: NSColor.textColor,
            .font: defaultFont
        ], range: NSRange(location: 0, length: length))
        storage.endEditing()
    }
}
