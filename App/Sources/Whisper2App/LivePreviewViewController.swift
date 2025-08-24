import AppKit

final class LivePreviewViewController: NSViewController {
    private let scroll = NSScrollView()
    private let textView = NSTextView()

    private(set) var currentText: String = ""

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 160))
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.string = "Speak to see live preview…"
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        container.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            scroll.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])

        self.view = container
    }

    func update(text: String) {
        currentText = text
        textView.string = text
    }

    func reset() {
        currentText = ""
        textView.string = "Speak to see live preview…"
    }
}
