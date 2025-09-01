import AppKit
import Whisper2Core

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let settingsStore: SettingsStore
    private var settings: Settings

    // Controls
    private let apiKeyField = PasteCapableSecureTextField()
    private let transcriptionPopup = NSPopUpButton()
    private let cleanupPopup = NSPopUpButton()
    private let transcriptionPromptEditor = MultilineTextEditor(editable: true)
    private let promptEditor = MultilineTextEditor(editable: true)
    private let keepAudioCheckbox = NSButton(checkboxWithTitle: "Keep audio files", target: nil, action: nil)
    private let hotkeyField = NSTextField()
    private let showAllModelsCheckbox = NSButton(checkboxWithTitle: "Show all models", target: nil, action: nil)
    private let useCleanupCheckbox = NSButton(checkboxWithTitle: "Enable cleanup (chat model)", target: nil, action: nil)

    // Rows we toggle visibility on
    private var cleanupModelRow: NSView?
    private var cleanupPromptRow: NSView?

    var onSaved: ((Settings) -> Void)?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        self.settings = settingsStore.load()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "WhisperPaste Settings"
        super.init(window: window)
        window.delegate = self
        setupUI()
        loadValues()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        // Show a Dock icon while Settings is visible for easy access
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // Auto-refresh models on first open if never refreshed
        if settings.lastModelRefresh == nil {
            refreshModels()
        }
    }

    private func setupUI() {
        guard let content = window?.contentView else { return }

        let rows: [NSView] = [
            makeRow(title: "OpenAI API Key:", field: apiKeyField),
            makeRow(title: "Transcription Model:", field: transcriptionPopup),
            makeTranscriptionPromptRow(),
            makeRow(title: "Keep audio files", field: keepAudioCheckbox),
            makeRow(title: "Hotkey:", field: hotkeyRecorder),
            cleanupSection()
        ]
        let vstack = NSStackView(views: rows)
        vstack.orientation = .vertical
        vstack.spacing = 12
        vstack.translatesAutoresizingMaskIntoConstraints = false

        // Bottom action bar: Refresh Models, spacer, Cancel, Save
        let refreshButton = NSButton(title: "Refresh Models", target: self, action: #selector(refreshModels))
        refreshButton.bezelStyle = .rounded
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}" // escape
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveTapped))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        let buttonBar = NSStackView(views: [refreshButton, spacer, cancelButton, saveButton])
        buttonBar.orientation = .horizontal
        buttonBar.spacing = 8
        buttonBar.alignment = .centerY
        buttonBar.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(vstack)
        content.addSubview(buttonBar)
        NSLayoutConstraint.activate([
            vstack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            vstack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            vstack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttonBar.topAnchor.constraint(greaterThanOrEqualTo: vstack.bottomAnchor, constant: 12),
            buttonBar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            buttonBar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttonBar.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
            spacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 8)
        ])

        // Configure fields
        apiKeyField.placeholderString = "sk-..."
        apiKeyField.translatesAutoresizingMaskIntoConstraints = false
        apiKeyField.controlSize = .regular
        apiKeyField.isBezeled = true

        // Items will be populated from persisted lists or via refreshModels()
        transcriptionPopup.removeAllItems()
        cleanupPopup.removeAllItems()

        transcriptionPromptEditor.translatesAutoresizingMaskIntoConstraints = false
        transcriptionPromptEditor.heightAnchor.constraint(equalToConstant: 120).isActive = true
        transcriptionPromptEditor.onChange = { [weak self] text in self?.settings.transcriptionPrompt = text }

        promptEditor.translatesAutoresizingMaskIntoConstraints = false
        promptEditor.heightAnchor.constraint(equalToConstant: 120).isActive = true
        promptEditor.onChange = { [weak self] text in self?.settings.cleanupPrompt = text }

        hotkeyField.placeholderString = "ctrl+shift+space"
        hotkeyRecorder.onChange = { [weak self] combo in self?.hotkeyField.stringValue = combo }

        showAllModelsCheckbox.target = self
        showAllModelsCheckbox.action = #selector(toggleShowAllModels)

        useCleanupCheckbox.target = self
        useCleanupCheckbox.action = #selector(toggleUseCleanup)
    }

    private func makeRow(title: String, field: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        let row = NSStackView(views: [label, field])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 160).isActive = true
        if let tf = field as? NSTextField { tf.translatesAutoresizingMaskIntoConstraints = false; tf.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true }
        if let popup = field as? NSPopUpButton { popup.translatesAutoresizingMaskIntoConstraints = false; popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true }
        return row
    }

    private func makePromptRow() -> NSView {
        let label = NSTextField(labelWithString: "Cleanup Prompt:")
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        let row = NSStackView(views: [label, promptEditor])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 160).isActive = true
        promptEditor.translatesAutoresizingMaskIntoConstraints = false
        promptEditor.heightAnchor.constraint(equalToConstant: 120).isActive = true
        // Ensure the editor expands and has a sensible minimum width
        promptEditor.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
        promptEditor.setContentHuggingPriority(.defaultLow, for: .horizontal)
        promptEditor.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        cleanupPromptRow = row
        return row
    }

    private func makeTranscriptionPromptRow() -> NSView {
        let label = NSTextField(labelWithString: "Transcription Prompt:")
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        let row = NSStackView(views: [label, transcriptionPromptEditor])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 160).isActive = true
        transcriptionPromptEditor.translatesAutoresizingMaskIntoConstraints = false
        transcriptionPromptEditor.heightAnchor.constraint(equalToConstant: 120).isActive = true
        transcriptionPromptEditor.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
        transcriptionPromptEditor.setContentHuggingPriority(.defaultLow, for: .horizontal)
        transcriptionPromptEditor.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return row
    }

    private lazy var hotkeyRecorder: HotkeyRecorderView = {
        let r = HotkeyRecorderView()
        r.hotkeyString = settings.hotkey
        return r
    }()

    private func cleanupSection() -> NSView {
        let box = NSBox()
        box.title = "Cleanup (chat model)"
        box.translatesAutoresizingMaskIntoConstraints = false
        let inner = NSStackView()
        inner.orientation = .vertical
        inner.spacing = 8
        inner.translatesAutoresizingMaskIntoConstraints = false
        let cleanupModel = makeRow(title: "Cleanup Model:", field: cleanupPopup)
        cleanupModelRow = cleanupModel
        inner.addArrangedSubview(useCleanupCheckbox)
        inner.addArrangedSubview(showAllModelsCheckbox)
        inner.addArrangedSubview(cleanupModel)
        inner.addArrangedSubview(makePromptRow())
        box.contentView = inner
        return box
    }

    private func loadValues() {
        apiKeyField.stringValue = Keychain.shared.getOpenAIKey() ?? settings.openAIKey ?? ""
        // Populate from persisted model lists if present (transcription list ignores showAll)
        transcriptionPopup.removeAllItems()
        if let models = settings.knownTranscriptionModels, !models.isEmpty {
            let filtered = Self.filteredModels(models, includeAll: false)
            transcriptionPopup.addItems(withTitles: filtered)
        }
        if transcriptionPopup.itemTitles.isEmpty { transcriptionPopup.addItems(withTitles: ["Loading models…"]) }
        transcriptionPopup.selectItem(withTitle: settings.transcriptionModel)

        cleanupPopup.removeAllItems()
        if let models = settings.knownCleanupModels, !models.isEmpty {
            let filtered = Self.filteredModels(models, includeAll: settings.showAllModels)
            cleanupPopup.addItems(withTitles: filtered)
        }
        if cleanupPopup.itemTitles.isEmpty { cleanupPopup.addItems(withTitles: ["Loading models…"]) }
        cleanupPopup.selectItem(withTitle: settings.cleanupModel)
        promptEditor.string = settings.cleanupPrompt
        transcriptionPromptEditor.string = settings.transcriptionPrompt
        useCleanupCheckbox.state = settings.useCleanup ? .on : .off
        keepAudioCheckbox.state = settings.keepAudioFiles ? .on : .off
        hotkeyField.stringValue = settings.hotkey
        hotkeyRecorder.hotkeyString = settings.hotkey
        showAllModelsCheckbox.state = settings.showAllModels ? .on : .off
        applyUseCleanupVisibility()
    }

    @objc private func saveTapped() {
        // Store API key to Keychain; keep JSON empty for security
        let typedKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        Keychain.shared.setOpenAIKey(typedKey.isEmpty ? nil : typedKey)
        settings.openAIKey = nil
        settings.transcriptionModel = transcriptionPopup.titleOfSelectedItem ?? settings.transcriptionModel
        settings.cleanupModel = cleanupPopup.titleOfSelectedItem ?? settings.cleanupModel
        settings.transcriptionPrompt = transcriptionPromptEditor.string
        settings.cleanupPrompt = promptEditor.string
        settings.useCleanup = (useCleanupCheckbox.state == .on)
        settings.keepAudioFiles = (keepAudioCheckbox.state == .on)
        settings.hotkey = hotkeyField.stringValue
        settings.showAllModels = (showAllModelsCheckbox.state == .on)
        do {
            try settingsStore.save(settings)
            onSaved?(settings)
            self.window?.close()
        } catch {
            NSSound.beep()
        }
    }

    @objc private func cancelTapped() {
        self.window?.close()
    }

    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        // Hide Dock icon again when Settings is closed
        NSApp.setActivationPolicy(.accessory)
    }

    @objc private func refreshModels() {
        let candidate = apiKeyField.stringValue.isEmpty ? (Keychain.shared.getOpenAIKey() ?? settings.openAIKey ?? "") : apiKeyField.stringValue
        guard !candidate.isEmpty else { NSSound.beep(); return }
        let apiKey = candidate
        let client = OpenAIClient()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let models = try client.listModels(apiKey: apiKey)
                let (transcription, cleanup) = Self.partitionModels(models: models)
                DispatchQueue.main.async {
                    // Persist lists and mark last refresh
                    self.settings.knownTranscriptionModels = transcription
                    self.settings.knownCleanupModels = cleanup
                    self.settings.lastModelRefresh = Date()
                    try? self.settingsStore.save(self.settings)

                    let showAll = self.settings.showAllModels
                    self.transcriptionPopup.removeAllItems()
                    self.transcriptionPopup.addItems(withTitles: Self.filteredModels(transcription, includeAll: false))
                    self.cleanupPopup.removeAllItems()
                    self.cleanupPopup.addItems(withTitles: Self.filteredModels(cleanup, includeAll: showAll))

                    // Select the user’s current choices, or fall back to first item
                    if self.transcriptionPopup.itemTitles.contains(self.settings.transcriptionModel) {
                        self.transcriptionPopup.selectItem(withTitle: self.settings.transcriptionModel)
                    } else {
                        self.transcriptionPopup.selectItem(at: 0)
                        self.settings.transcriptionModel = self.transcriptionPopup.titleOfSelectedItem ?? self.settings.transcriptionModel
                        try? self.settingsStore.save(self.settings)
                    }
                    if self.cleanupPopup.itemTitles.contains(self.settings.cleanupModel) {
                        self.cleanupPopup.selectItem(withTitle: self.settings.cleanupModel)
                    } else {
                        self.cleanupPopup.selectItem(at: 0)
                        self.settings.cleanupModel = self.cleanupPopup.titleOfSelectedItem ?? self.settings.cleanupModel
                        try? self.settingsStore.save(self.settings)
                    }
                }
            } catch {
                DispatchQueue.main.async { NSSound.beep() }
            }
        }
    }

    private static func partitionModels(models: [String]) -> ([String], [String]) {
        // Transcription: whisper or transcribe
        let trans = models.filter { id in
            id.localizedCaseInsensitiveContains("whisper") || id.localizedCaseInsensitiveContains("transcribe")
        }
        // Cleanup: chat-capable gpt-* models excluding audio-only or non-chat variants
        let excluded = ["audio", "tts", "realtime", "embed", "transcribe", "whisper"]
        let cleanAll = models.filter { $0.hasPrefix("gpt-") }
        let clean = cleanAll.filter { id in !excluded.contains { id.localizedCaseInsensitiveContains($0) } }
        return (trans.isEmpty ? ["whisper-1", "gpt-4o-mini-transcribe"] : trans,
                clean.isEmpty ? ["gpt-4o-mini", "gpt-4o"] : clean)
    }

    // Hide models containing "preview" or ending with two digits when includeAll == false
    static func filteredModels(_ models: [String], includeAll: Bool) -> [String] {
        guard !includeAll else { return models }
        return models.filter { id in
            if id.localizedCaseInsensitiveContains("preview") { return false }
            // Ends with two digits? e.g., ...-24 or ...06 or ...2024-08
            let lastTwo = String(id.suffix(2))
            let endsWithTwoDigits = lastTwo.count == 2 && lastTwo.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
            if endsWithTwoDigits { return false }
            return true
        }
    }

    @objc private func toggleShowAllModels() {
        settings.showAllModels = (showAllModelsCheckbox.state == .on)
        // Re-apply filtering to cleanup list only without refetching
        let trans = settings.knownTranscriptionModels ?? []
        let clean = settings.knownCleanupModels ?? []
        transcriptionPopup.removeAllItems()
        transcriptionPopup.addItems(withTitles: Self.filteredModels(trans, includeAll: false))
        cleanupPopup.removeAllItems()
        cleanupPopup.addItems(withTitles: Self.filteredModels(clean, includeAll: settings.showAllModels))
        // Keep current selections if possible
        transcriptionPopup.selectItem(withTitle: settings.transcriptionModel)
        cleanupPopup.selectItem(withTitle: settings.cleanupModel)
    }

    @objc private func toggleUseCleanup() {
        settings.useCleanup = (useCleanupCheckbox.state == .on)
        applyUseCleanupVisibility()
    }

    private func applyUseCleanupVisibility() {
        let show = (useCleanupCheckbox.state == .on)
        cleanupPopup.isHidden = !show
        cleanupModelRow?.isHidden = !show
        cleanupPromptRow?.isHidden = !show
        showAllModelsCheckbox.isHidden = !show
    }
}
