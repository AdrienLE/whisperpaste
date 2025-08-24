import AppKit
import Whisper2Core

final class SettingsWindowController: NSWindowController {
    private let settingsStore: SettingsStore
    private var settings: Settings

    // Controls
    private let apiKeyField = NSSecureTextField()
    private let transcriptionPopup = NSPopUpButton()
    private let cleanupPopup = NSPopUpButton()
    private let promptTextView = NSTextView()
    private let promptScroll = NSScrollView()
    private let keepAudioCheckbox = NSButton(checkboxWithTitle: "Keep audio files", target: nil, action: nil)
    private let hotkeyField = NSTextField()

    var onSaved: ((Settings) -> Void)?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        self.settings = settingsStore.load()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "Whisper2 Settings"
        super.init(window: window)
        setupUI()
        loadValues()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupUI() {
        guard let content = window?.contentView else { return }

        let rows: [NSView] = [
            makeRow(title: "OpenAI API Key:", field: apiKeyField),
            makeRow(title: "Transcription Model:", field: transcriptionPopup),
            makeRow(title: "Cleanup Model:", field: cleanupPopup),
            makePromptSection(),
            makeRow(title: "Hotkey:", field: hotkeyField),
            keepAudioCheckbox
        ]
        let vstack = NSStackView(views: rows)
        vstack.orientation = .vertical
        vstack.spacing = 12
        vstack.translatesAutoresizingMaskIntoConstraints = false

        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveTapped))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(vstack)
        content.addSubview(saveButton)
        NSLayoutConstraint.activate([
            vstack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            vstack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            vstack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            saveButton.topAnchor.constraint(greaterThanOrEqualTo: vstack.bottomAnchor, constant: 12),
            saveButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            saveButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
        ])

        // Configure fields
        apiKeyField.placeholderString = "sk-..."
        apiKeyField.translatesAutoresizingMaskIntoConstraints = false
        apiKeyField.controlSize = .regular
        apiKeyField.isBezeled = true

        transcriptionPopup.addItems(withTitles: ["whisper-1", "gpt-4o-mini-transcribe"]) 
        cleanupPopup.addItems(withTitles: ["gpt-4o-mini", "gpt-4o"]) 

        promptTextView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        promptTextView.isVerticallyResizable = true
        promptTextView.isHorizontallyResizable = false
        promptScroll.documentView = promptTextView
        promptScroll.hasVerticalScroller = true
        promptScroll.translatesAutoresizingMaskIntoConstraints = false
        promptScroll.heightAnchor.constraint(equalToConstant: 120).isActive = true

        hotkeyField.placeholderString = "ctrl+shift+space"
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

    private func makePromptSection() -> NSView {
        let label = NSTextField(labelWithString: "Cleanup Prompt:")
        label.alignment = .left
        let v = NSStackView(views: [label, promptScroll])
        v.orientation = .vertical
        v.spacing = 6
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func loadValues() {
        apiKeyField.stringValue = settings.openAIKey ?? ""
        if !transcriptionPopup.itemTitles.contains(settings.transcriptionModel) {
            transcriptionPopup.addItem(withTitle: settings.transcriptionModel)
        }
        transcriptionPopup.selectItem(withTitle: settings.transcriptionModel)
        if !cleanupPopup.itemTitles.contains(settings.cleanupModel) {
            cleanupPopup.addItem(withTitle: settings.cleanupModel)
        }
        cleanupPopup.selectItem(withTitle: settings.cleanupModel)
        promptTextView.string = settings.cleanupPrompt
        keepAudioCheckbox.state = settings.keepAudioFiles ? .on : .off
        hotkeyField.stringValue = settings.hotkey
    }

    @objc private func saveTapped() {
        settings.openAIKey = apiKeyField.stringValue.isEmpty ? nil : apiKeyField.stringValue
        settings.transcriptionModel = transcriptionPopup.titleOfSelectedItem ?? settings.transcriptionModel
        settings.cleanupModel = cleanupPopup.titleOfSelectedItem ?? settings.cleanupModel
        settings.cleanupPrompt = promptTextView.string
        settings.keepAudioFiles = (keepAudioCheckbox.state == .on)
        settings.hotkey = hotkeyField.stringValue
        do {
            try settingsStore.save(settings)
            onSaved?(settings)
            self.window?.close()
        } catch {
            NSSound.beep()
        }
    }
}
