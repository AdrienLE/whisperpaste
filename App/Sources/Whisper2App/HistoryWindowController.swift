import AppKit
import AVFoundation
import Whisper2Core

final class HistoryWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let historyStore: HistoryStore
    private var items: [TranscriptionRecord] = []
    private var player: AVAudioPlayer?

    private let table = NSTableView()
    private let scroll = NSScrollView()
    private let playBtn = NSButton(title: "Play", target: nil, action: nil)
    private let revealBtn = NSButton(title: "Reveal in Finder", target: nil, action: nil)
    private let cleanBtn = NSButton(title: "Remove Missing Audio", target: nil, action: nil)

    init(historyStore: HistoryStore) {
        self.historyStore = historyStore
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 360),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "WhisperPaste History"
        super.init(window: window)
        setupUI()
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        reload()
        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupUI() {
        guard let content = window?.contentView else { return }

        let dateCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateCol.title = "Date"
        dateCol.width = 160
        let previewCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("preview"))
        previewCol.title = "Preview"
        previewCol.width = 200
        let rawCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("raw"))
        rawCol.title = "Transcribed"
        rawCol.width = 220
        let cleanCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clean"))
        cleanCol.title = "Cleaned"
        cleanCol.width = 220

        table.addTableColumn(dateCol)
        table.addTableColumn(previewCol)
        table.addTableColumn(rawCol)
        table.addTableColumn(cleanCol)
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = false
        table.allowsEmptySelection = false
        table.delegate = self
        table.dataSource = self

        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)
        playBtn.target = self
        playBtn.action = #selector(playAudio)
        playBtn.toolTip = "Play the selected entry's audio file"
        revealBtn.target = self
        revealBtn.action = #selector(revealAudio)
        revealBtn.toolTip = "Reveal the selected entry's audio file in Finder"
        cleanBtn.target = self
        cleanBtn.action = #selector(cleanMissing)
        cleanBtn.toolTip = "Remove history entries whose audio file is missing"
        let buttons = NSStackView(views: [
            NSButton(title: "Copy Raw", target: self, action: #selector(copyRaw)),
            NSButton(title: "Copy Cleaned", target: self, action: #selector(copyCleaned)),
            playBtn,
            revealBtn,
            cleanBtn,
            NSButton(title: "Refresh", target: self, action: #selector(refresh))
        ])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttons)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            scroll.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -10),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10)
        ])
    }

    private func reload() {
        items = historyStore.load()
        table.reloadData()
        // Ensure a single selection by default
        if !items.isEmpty {
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        updateButtonsForSelection()
    }

    // MARK: - DataSource/Delegate
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        let id = tableColumn?.identifier.rawValue
        let text: String
        switch id {
        case "date":
            let fmt = DateFormatter()
            fmt.dateStyle = .short
            fmt.timeStyle = .short
            text = fmt.string(from: item.createdAt)
        case "preview": text = item.previewText ?? ""
        case "raw": text = item.rawText
        case "clean": text = item.cleanedText
        default: text = ""
        }
        let cell = NSTableCellView()
        let label = NSTextField(labelWithString: text)
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    // MARK: - Actions
    @objc private func copyRaw() { copy(column: \.rawText) }
    @objc private func copyCleaned() { copy(column: \.cleanedText) }
    @objc private func refresh() { reload() }
    @objc private func cleanMissing() {
        let alert = NSAlert()
        alert.messageText = "Remove entries with missing audio?"
        alert.informativeText = "This will remove any history items whose audio file cannot be found on disk."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            try? historyStore.cleanMissingAudioReferences(); reload()
        }
    }
    @objc private func playAudio() {
        guard let path = selectedAudioPath() else { NSSound.beep(); return }
        do {
            player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            player?.prepareToPlay()
            player?.play()
        } catch { NSSound.beep() }
    }
    @objc private func revealAudio() {
        guard let path = selectedAudioPath() else { NSSound.beep(); return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func copy(column: KeyPath<TranscriptionRecord, String>) {
        var row = table.selectedRow
        if row < 0 && !items.isEmpty { row = 0 } // default to first entry if none selected
        guard row >= 0, row < items.count else { NSSound.beep(); return }
        let paste = NSPasteboard.general
        paste.clearContents()
        paste.setString(items[row][keyPath: column], forType: .string)
    }

    private func selectedAudioPath() -> String? {
        let row = table.selectedRow
        guard row >= 0, row < items.count else { return nil }
        guard let path = items[row].audioFilePath, FileManager.default.fileExists(atPath: path) else { return nil }
        return path
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonsForSelection()
    }

    private func updateButtonsForSelection() {
        let hasAudio = (selectedAudioPath() != nil)
        playBtn.isEnabled = hasAudio
        revealBtn.isEnabled = hasAudio
    }
}
