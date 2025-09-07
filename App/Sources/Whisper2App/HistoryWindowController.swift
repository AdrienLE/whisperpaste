import AppKit
import AVFoundation
import WhisperpasteCore

final class HistoryWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let historyStore: HistoryStore
    private var items: [TranscriptionRecord] = []
    private var player: AVAudioPlayer?

    private let table = NSTableView()
    private let scroll = NSScrollView()
    private let clearAudioBtn = NSButton(title: "Clear All Audio", target: nil, action: nil)
    private let clearHistoryBtn = NSButton(title: "Clear History", target: nil, action: nil)
    private let refreshBtn = NSButton(title: "Refresh", target: nil, action: nil)

    private struct CellKey: Hashable { let row: Int; let column: String }
    private var activeCell: CellKey? = nil

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

        let playCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("play"))
        playCol.title = ""
        playCol.width = 28
        playCol.minWidth = 24
        playCol.maxWidth = 36

        let dateCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateCol.title = "Date"
        dateCol.width = 140
        let previewCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("preview"))
        previewCol.title = "Preview"
        previewCol.width = 200
        let rawCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("raw"))
        rawCol.title = "Transcribed"
        rawCol.width = 220
        let cleanCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clean"))
        cleanCol.title = "Cleaned"
        cleanCol.width = 220

        table.addTableColumn(playCol)
        table.addTableColumn(dateCol)
        table.addTableColumn(previewCol)
        table.addTableColumn(rawCol)
        table.addTableColumn(cleanCol)
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = true
        table.allowsEmptySelection = true
        table.delegate = self
        table.dataSource = self
        table.target = self
        table.doubleAction = #selector(tableDoubleClicked(_:))

        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)
        clearAudioBtn.target = self
        clearAudioBtn.action = #selector(clearAllAudio)
        clearAudioBtn.toolTip = "Delete audio files from all entries but keep text"
        clearHistoryBtn.target = self
        clearHistoryBtn.action = #selector(clearHistory)
        clearHistoryBtn.toolTip = "Remove all history entries (text and audio)"
        refreshBtn.target = self
        refreshBtn.action = #selector(refresh)

        let buttons = NSStackView(views: [
            clearAudioBtn,
            clearHistoryBtn,
            refreshBtn
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
        updateButtonsForSelection()
    }

    // MARK: - DataSource/Delegate
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        // Default collapsed height
        guard let active = activeCell, active.row == row else { return 28 }
        // Compute height based on the active cell's text and column width
        let padding: CGFloat = 8
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        func heightFor(text: String, width: CGFloat) -> CGFloat {
            guard width > 0 else { return 0 }
            let attr = NSAttributedString(string: text, attributes: [.font: font])
            let rect = attr.boundingRect(with: NSSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading])
            return ceil(rect.height)
        }
        guard let col = table.tableColumns.first(where: { $0.identifier.rawValue == active.column }) else { return 28 }
        let w = col.width - 8
        let item = items[row]
        let text: String = {
            switch active.column {
            case "date":
                let fmt = DateFormatter(); fmt.dateStyle = .short; fmt.timeStyle = .short
                return fmt.string(from: item.createdAt)
            case "preview": return item.previewText ?? ""
            case "raw": return item.rawText
            case "clean": return item.cleanedText
            default: return ""
            }
        }()
        let h = heightFor(text: text, width: w)
        return max(28, h + padding)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        let id = tableColumn?.identifier.rawValue
        if id == "play" {
            let cell = NSTableCellView()
            let btn = NSButton()
            btn.bezelStyle = .inline
            btn.isBordered = false
            btn.title = ""
            if let path = item.audioFilePath, FileManager.default.fileExists(atPath: path) {
                if let img = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play") { btn.image = img } else { btn.title = "▶︎" }
                btn.isEnabled = true
                btn.toolTip = "Play audio"
            } else {
                if let img = NSImage(systemSymbolName: "play.slash.fill", accessibilityDescription: "No Audio") { btn.image = img } else { btn.title = "–" }
                btn.isEnabled = false
                btn.toolTip = "No audio available"
            }
            btn.target = self
            btn.action = #selector(playButtonTapped(_:))
            btn.tag = row
            btn.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                btn.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell
        }
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
        let tf = NSTextField()
        tf.isEditable = false
        tf.isBordered = false
        tf.drawsBackground = false
        tf.allowsEditingTextAttributes = false
        tf.translatesAutoresizingMaskIntoConstraints = false
        let isActive = (activeCell?.row == row && activeCell?.column == id)
        tf.isSelectable = isActive
        if isActive {
            tf.lineBreakMode = .byWordWrapping
            tf.maximumNumberOfLines = 0
            tf.usesSingleLineMode = false
            tf.cell?.wraps = true
        } else {
            tf.lineBreakMode = .byTruncatingMiddle
            tf.maximumNumberOfLines = 1
            tf.usesSingleLineMode = true
            tf.cell?.wraps = false
        }
        tf.stringValue = text
        // Disclosure toggle button to indicate/click expand state
        let disc = NSButton()
        disc.isBordered = false
        disc.bezelStyle = .inline
        disc.title = ""
        let rightImg = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Expand")
        let downImg = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Collapse")
        disc.image = isActive ? (downImg ?? NSImage()) : (rightImg ?? NSImage())
        if disc.image == NSImage() { disc.title = isActive ? "▾" : "▸" }
        disc.target = self
        disc.action = #selector(toggleDisclosure(_:))
        disc.tag = row
        disc.identifier = NSUserInterfaceItemIdentifier("disc:\(id ?? "")")
        disc.translatesAutoresizingMaskIntoConstraints = false

        let hstack = NSStackView(views: [disc, tf])
        hstack.orientation = .horizontal
        hstack.spacing = 4
        hstack.alignment = .centerY
        hstack.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(hstack)
        NSLayoutConstraint.activate([
            hstack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            hstack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            hstack.topAnchor.constraint(equalTo: cell.topAnchor, constant: 2),
            hstack.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -2),
            disc.widthAnchor.constraint(equalToConstant: 10)
        ])
        if isActive {
            DispatchQueue.main.async { [weak tf] in
                guard let tf = tf else { return }
                tf.window?.makeFirstResponder(tf)
                tf.selectText(nil)
            }
        }
        return cell
    }

    // MARK: - Actions
    @objc private func refresh() { reload() }
    @objc private func playButtonTapped(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < items.count else { return }
        guard let path = items[row].audioFilePath, FileManager.default.fileExists(atPath: path) else { NSSound.beep(); return }
        do {
            player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            player?.prepareToPlay()
            player?.play()
        } catch { NSSound.beep() }
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
        // Enable Clear All Audio only when at least one record has an accessible audio file
        let anyAudio = items.contains { rec in
            if let p = rec.audioFilePath { return FileManager.default.fileExists(atPath: p) }
            return false
        }
        clearAudioBtn.isEnabled = anyAudio
    }

    // MARK: - Bulk actions
    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear all history?"
        alert.informativeText = "This will remove all entries (text and audio references)."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            try? historyStore.clearAll()
            reload()
        }
    }

    @objc private func clearAllAudio() {
        let alert = NSAlert()
        alert.messageText = "Clear all audio files?"
        alert.informativeText = "This will delete audio files on disk and keep the text history."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete Audio")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            try? historyStore.clearAllAudioReferences(deleteFiles: true)
            reload()
        }
    }

    // MARK: - Delete single
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 { // delete
            deleteSelected()
            return
        }
        if event.keyCode == 53 { // escape closes window
            self.window?.close(); return
        }
        if event.keyCode == 123 { // left arrow: collapse active cell
            if let active = activeCell {
                let row = active.row
                activeCell = nil
                table.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
                table.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integersIn: 0..<table.numberOfColumns))
                return
            }
        }
        // Cmd+A select all
        if event.modifierFlags.contains(.command), let chars = event.charactersIgnoringModifiers, chars.lowercased() == "a" {
            table.selectAll(nil)
            return
        }
        super.keyDown(with: event)
    }

    @objc private func deleteSelected() {
        let selected = table.selectedRowIndexes
        guard !selected.isEmpty else { NSSound.beep(); return }
        let alert = NSAlert()
        alert.messageText = selected.count == 1 ? "Delete selected entry?" : "Delete \(selected.count) entries?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            // Delete from bottom-most index to preserve positions
            selected.reversed().forEach { try? historyStore.delete(at: $0) }
            reload()
        }
    }

    @objc private func tableDoubleClicked(_ sender: Any?) {
        let row = table.clickedRow
        let colIdx = table.clickedColumn
        guard row >= 0 && row < items.count, colIdx >= 0 && colIdx < table.tableColumns.count else { return }
        let id = table.tableColumns[colIdx].identifier.rawValue
        guard id != "play" else { return }
        let key = CellKey(row: row, column: id)
        if activeCell == key {
            activeCell = nil
        } else {
            activeCell = key
        }
        table.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
        table.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integersIn: 0..<table.numberOfColumns))
    }

    @objc private func toggleDisclosure(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < items.count else { return }
        let idRaw = sender.identifier?.rawValue ?? ""
        let parts = idRaw.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let id = parts[1]
        let key = CellKey(row: row, column: id)
        if activeCell == key { activeCell = nil } else { activeCell = key }
        table.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
        table.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integersIn: 0..<table.numberOfColumns))
    }
}
