import AppKit
import Foundation
import Whisper2Core

final class MenuBarController: NSObject {
    private(set) var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var eventMonitor: Any?
    private var localEventMonitor: Any?
    private var isRecording = false
    private let previewVC = LivePreviewViewController()
    private var recorder: SpeechRecorder?
    private let hotkeyManager = HotkeyManager()

    private let settingsStore = SettingsStore()
    private let historyStore = HistoryStore()
    private var settingsWC: SettingsWindowController?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Whisper2") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "W2"
            }
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.contentViewController = previewVC
        popover.behavior = .applicationDefined

        // Enforce API key on launch
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let s = self.settingsStore.load()
            if (s.openAIKey ?? "").isEmpty {
                self.presentSettings(force: true)
            }
            self.registerHotkey(from: s.hotkey)
            self.installEventMonitors()
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            toggleRecording()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "History", action: #selector(openHistory), keyEquivalent: "h"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil) // show the menu
        statusItem.menu = nil
    }

    @objc private func menuToggleRecording() { toggleRecording() }

    private func toggleRecording() {
        guard let button = statusItem.button else { return }
        // Must have API key to proceed with transcription
        let s = settingsStore.load()
        if (s.openAIKey ?? "").isEmpty {
            presentSettings(force: true)
            NSSound.beep()
            return
        }
        if isRecording {
            isRecording = false
            recorder?.stop()
            // Keep popover open and show transcribing state
            previewVC.setState(.transcribing)
            if !popover.isShown, let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            }
            runTranscriptionPipeline()
        } else {
            isRecording = true
            let rec = SpeechRecorder(historyStore: historyStore, settingsStore: settingsStore)
            rec.onPreview = { [weak self] text in
                DispatchQueue.main.async { self?.previewVC.update(text: text) }
            }
            rec.onError = { [weak self] error in
                NSLog("Speech error: \(error)")
                DispatchQueue.main.async { self?.previewVC.setState(.error(error.localizedDescription)) }
            }
            rec.onFinish = { [weak self] _ in /* no-op, handled on stop */ self?.isRecording = false }
            recorder = rec
            rec.start()
            previewVC.setState(.recording)
            setRecordingIcon(true)
            if !popover.isShown {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            }
            previewVC.onStop = { [weak self] in self?.toggleRecording() }
        }
    }

    private func runTranscriptionPipeline() {
        previewVC.setState(.transcribing)
        let settings = settingsStore.load()
        guard let audioURL = recorder?.recordedFileURL else {
            // Fallback: no audio captured, use preview text
            finalizeRecord(raw: previewVC.currentText, cleaned: previewVC.currentText, audioURL: nil)
            return
        }
        guard let key = settings.openAIKey, !key.isEmpty else {
            // No API key, use preview text
            finalizeRecord(raw: previewVC.currentText, cleaned: previewVC.currentText, audioURL: settings.keepAudioFiles ? audioURL : nil)
            if !settings.keepAudioFiles { try? FileManager.default.removeItem(at: audioURL) }
            return
        }

        let client = OpenAIClient()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let raw = try client.transcribe(apiKey: key, audioFileURL: audioURL, model: settings.transcriptionModel)
                DispatchQueue.main.async { self.previewVC.setState(.cleaning) }
                let cleaned = try client.cleanup(apiKey: key, text: raw, prompt: settings.cleanupPrompt, model: settings.cleanupModel)
                DispatchQueue.main.async {
                    self.finalizeRecord(raw: raw, cleaned: cleaned, audioURL: settings.keepAudioFiles ? audioURL : nil)
                    if !settings.keepAudioFiles { try? FileManager.default.removeItem(at: audioURL) }
                }
            } catch {
                DispatchQueue.main.async {
                    NSLog("OpenAI pipeline error: \(error)")
                    self.previewVC.setState(.error("Transcription failed"))
                    self.finalizeRecord(raw: self.previewVC.currentText, cleaned: self.previewVC.currentText, audioURL: settings.keepAudioFiles ? audioURL : nil)
                    if !settings.keepAudioFiles { try? FileManager.default.removeItem(at: audioURL) }
                }
            }
        }
    }

    private func finalizeRecord(raw: String, cleaned: String, audioURL: URL?) {
        let trimmedRaw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClean = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRaw.isEmpty || !trimmedClean.isEmpty {
            let record = TranscriptionRecord(rawText: trimmedRaw, cleanedText: trimmedClean, audioFilePath: audioURL?.path)
            try? historyStore.append(record)
            // Copy cleaned (or raw) text to clipboard after processing
            let textToCopy = trimmedClean.isEmpty ? trimmedRaw : trimmedClean
            if !textToCopy.isEmpty {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(textToCopy, forType: .string)
            }
        }
        previewVC.reset()
        previewVC.setState(.idle)
        setRecordingIcon(false)
    }

    @objc private func openSettings() { presentSettings(force: false) }

    private func presentSettings(force: Bool) {
        if settingsWC == nil {
            let wc = SettingsWindowController(settingsStore: settingsStore)
            wc.onSaved = { [weak self] s in
                self?.settingsWC = nil
                self?.registerHotkey(from: s.hotkey)
            }
            settingsWC = wc
        }
        settingsWC?.show()
        if force { NSApp.activate(ignoringOtherApps: true) }
    }

    @objc private func openHistory() {
        HistoryWindowController(historyStore: historyStore).show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func setRecordingIcon(_ recording: Bool) {
        guard let button = statusItem.button else { return }
        let name = recording ? "record.circle" : "waveform"
        if let img = NSImage(systemSymbolName: name, accessibilityDescription: "Whisper2") {
            img.isTemplate = true
            button.image = img
        } else {
            button.title = recording ? "●" : "W2"
        }
    }

    private func registerHotkey(from string: String) {
        let hk = Hotkey.parse(string)
        hotkeyManager.register(hotkey: hk) { [weak self] in
            DispatchQueue.main.async { self?.toggleRecording() }
        }
    }

    private func installEventMonitors() {
        if eventMonitor == nil {
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.maybeClosePopoverOnOutsideClick()
            }
        }
        if localEventMonitor == nil {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.maybeClosePopoverOnOutsideClick()
                return event
            }
        }
    }

    private func maybeClosePopoverOnOutsideClick() {
        guard popover.isShown else { return }
        if previewVC.state == .idle {
            popover.performClose(nil)
        } else {
            // Keep it open: if it somehow closed, reopen under the status item
            if let button = statusItem.button, !popover.isShown {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            }
        }
    }
}
