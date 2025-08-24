import AppKit
import Whisper2Core

final class SettingsWindowController: NSWindowController {
    private let settingsStore: SettingsStore
    private var settings: Settings

    private let apiKeyField = NSSecureTextField()
    private let transcriptionModelField = NSTextField()
    private let cleanupModelField = NSTextField()
    private let promptField = NSTextField()
    private let keepAudioCheckbox = NSButton(checkboxWithTitle: "Keep audio files", target: nil, action: nil)
    private let hotkeyField = NSTextField()

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        self.settings = settingsStore.load()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 300),
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
        let grid = NSGridView(views: [
            [label("OpenAI API Key:"), apiKeyField],
            [label("Transcription Model:"), transcriptionModelField],
            [label("Cleanup Model:"), cleanupModelField],
            [label("Cleanup Prompt:"), promptField],
            [label("Hotkey:"), hotkeyField]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 8
        grid.columnSpacing = 12

        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveTapped))
        saveButton.bezelStyle = .rounded
        let stack = NSStackView(views: [grid, keepAudioCheckbox, saveButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -16)
        ])
        apiKeyField.placeholderString = "sk-..."
        transcriptionModelField.placeholderString = "whisper-1"
        cleanupModelField.placeholderString = "gpt-4o-mini"
        promptField.placeholderString = "Rewrite text for clarity and grammar."
        hotkeyField.placeholderString = "ctrl+shift+space"
    }

    private func label(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.alignment = .right
        return l
    }

    private func loadValues() {
        apiKeyField.stringValue = settings.openAIKey ?? ""
        transcriptionModelField.stringValue = settings.transcriptionModel
        cleanupModelField.stringValue = settings.cleanupModel
        promptField.stringValue = settings.cleanupPrompt
        keepAudioCheckbox.state = settings.keepAudioFiles ? .on : .off
        hotkeyField.stringValue = settings.hotkey
    }

    @objc private func saveTapped() {
        settings.openAIKey = apiKeyField.stringValue.isEmpty ? nil : apiKeyField.stringValue
        settings.transcriptionModel = transcriptionModelField.stringValue
        settings.cleanupModel = cleanupModelField.stringValue
        settings.cleanupPrompt = promptField.stringValue
        settings.keepAudioFiles = (keepAudioCheckbox.state == .on)
        settings.hotkey = hotkeyField.stringValue
        do {
            try settingsStore.save(settings)
        } catch {
            NSSound.beep()
        }
    }
}
