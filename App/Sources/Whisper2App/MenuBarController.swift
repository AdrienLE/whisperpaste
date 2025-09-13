import AppKit
import Foundation
import AVFoundation
import WhisperpasteCore

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
    private var benchmarkWC: BenchmarkWindowController?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let img = Self.loadStatusIcon() {
                img.isTemplate = true
                button.image = img
            } else if let sf = NSImage(systemSymbolName: "waveform", accessibilityDescription: "WhisperPaste") {
                sf.isTemplate = true
                button.image = sf
            } else {
                button.title = "WP"
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
        menu.addItem(NSMenuItem(title: "Benchmark", action: #selector(openBenchmark), keyEquivalent: "b"))
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
        if ((settingsStore.load().openAIKey ?? "").isEmpty) {
            presentSettings(force: true)
            NSSound.beep()
            return
        }
        // If we are currently processing (transcribing/cleaning), ignore toggle and keep popover visible
        switch previewVC.state {
        case .transcribing, .cleaning:
            if !popover.isShown {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            }
            return
        default:
            break
        }
        if isRecording {
            isRecording = false
            // Keep popover open and show transcribing state
            previewVC.setState(.transcribing)
            if !popover.isShown, let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            }
            // Wait for recorder to finish writing the file before starting pipeline
            recorder?.onFinish = { [weak self] url in
                self?.isRecording = false
                DispatchQueue.main.async {
                    self?.runTranscriptionPipeline(recordedURL: url)
                }
            }
            recorder?.stop()
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
            rec.onFinish = { [weak self] _ in /* handled on stop */ self?.isRecording = false }
            recorder = rec
            rec.start()
            setRecordingIcon(true)
            if !popover.isShown {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            }
            previewVC.setState(.recording)
            previewVC.onStop = { [weak self] in self?.toggleRecording() }
            previewVC.onAbort = { [weak self] in self?.abortRecording() }
        }
    }

    private func abortRecording() {
        guard isRecording else { return }
        // Abort: stop recorder but do not run pipeline; delete captured audio if any
        let recorderRef = recorder
        recorderRef?.onFinish = { [weak self] url in
            guard let self = self else { return }
            self.isRecording = false
            if let u = url {
                try? FileManager.default.removeItem(at: u)
            }
            DispatchQueue.main.async {
                self.previewVC.reset()
                self.previewVC.setState(.idle)
                self.setRecordingIcon(false)
            }
        }
        recorderRef?.stop()
    }

    private func runTranscriptionPipeline(recordedURL: URL? = nil) {
        previewVC.setState(.transcribing)
        let settings = settingsStore.load()
        guard let audioURL = recordedURL ?? recorder?.recordedFileURL else {
            // Fallback: no audio captured, use preview text
            NSLog("Pipeline: No audio captured; using live preview text")
            finalizeRecord(raw: previewVC.currentText, cleaned: previewVC.currentText, audioURL: nil, source: "preview")
            return
        }
        guard let key = settings.openAIKey, !key.isEmpty else {
            // No API key, use preview text
            NSLog("Pipeline: Missing API key; using live preview text")
            finalizeRecord(raw: previewVC.currentText, cleaned: previewVC.currentText, audioURL: settings.keepAudioFiles ? audioURL : nil, source: "preview")
            if !settings.keepAudioFiles { try? FileManager.default.removeItem(at: audioURL) }
            return
        }

        let client = OpenAIClient()
        let pipelineStart = Date()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            // Prepare audio: convert to m4a (AAC) for API compatibility/size
            let convertStart = Date()
            var (preparedURL, exportError) = self.encodeToM4ALowBitrate(originalURL: audioURL)
            if preparedURL == nil {
                (preparedURL, exportError) = self.prepareAudioForUploadDetailed(originalURL: audioURL)
            }
            let convertDuration = Date().timeIntervalSince(convertStart)
            if let u = preparedURL {
                NSLog("Pipeline: Conversion to m4a took %.2fs (file=\(u.lastPathComponent))", convertDuration)
            } else {
                NSLog("Pipeline: Conversion to m4a failed after %.2fs: \(exportError ?? "unknown error")", convertDuration)
                if let details = exportError {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Audio Compression Failed"
                        alert.informativeText = details + "\nProceeding with WAV upload."
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
            let uploadURL = preparedURL ?? audioURL
            // Stage 1: Transcribe
            let rawResult: Result<String, Error>
            do {
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: uploadURL.path)[.size] as? NSNumber)?.intValue ?? -1
                NSLog("Pipeline: Transcribing with model=\(settings.transcriptionModel), file=\(uploadURL.lastPathComponent), size=\(fileSize) bytes")
                let t0 = Date()
                let raw = try client.transcribe(apiKey: key, audioFileURL: uploadURL, model: settings.transcriptionModel, prompt: settings.transcriptionPrompt)
                let tDur = Date().timeIntervalSince(t0)
                NSLog("Pipeline: Transcribe duration %.2fs", tDur)
                rawResult = .success(raw)
            } catch {
                NSLog("Pipeline: Transcribe error: \(error.localizedDescription)")
                rawResult = .failure(error)
            }

            switch rawResult {
            case .failure(let error):
                let details = (error as NSError).localizedDescription
                DispatchQueue.main.async {
                    let msg = "Transcription failed. Copied live preview."
                    self.previewVC.setErrorDetails(details)
                    self.previewVC.setState(.error(msg))
                    self.finalizeRecord(raw: self.previewVC.currentText, cleaned: self.previewVC.currentText, audioURL: settings.keepAudioFiles ? uploadURL : nil, source: "error", resetUI: false)
                    let alert = NSAlert()
                    alert.messageText = "Transcription Failed"
                    alert.informativeText = details
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                    self.previewVC.reset()
                    self.previewVC.setState(.idle)
                    self.setRecordingIcon(false)
                    if !settings.keepAudioFiles {
                        try? FileManager.default.removeItem(at: audioURL)
                        if uploadURL != audioURL { try? FileManager.default.removeItem(at: uploadURL) }
                    } else if uploadURL != audioURL {
                        // Prefer keeping the compressed file; remove raw to save space
                        try? FileManager.default.removeItem(at: audioURL)
                    }
                }
                return
            case .success(let raw):
                NSLog("Pipeline: Raw length=\(raw.count) chars")
                if settings.useCleanup {
                    DispatchQueue.main.async { self.previewVC.setState(.cleaning) }
                    // Stage 2: Cleanup
                    let cleanResult: Result<String, Error>
                    do {
                        NSLog("Pipeline: Cleaning with model=\(settings.cleanupModel)")
                        let c0 = Date()
                        let cleaned = try client.cleanup(apiKey: key, text: raw, prompt: settings.cleanupPrompt, model: settings.cleanupModel)
                        let cDur = Date().timeIntervalSince(c0)
                        NSLog("Pipeline: Cleanup duration %.2fs", cDur)
                        cleanResult = .success(cleaned)
                    } catch {
                        NSLog("Pipeline: Cleanup error: \(error.localizedDescription)")
                        cleanResult = .failure(error)
                    }
                    switch cleanResult {
                    case .success(let cleaned):
                        NSLog("Pipeline: Cleaned length=\(cleaned.count) chars")
                        DispatchQueue.main.async {
                            self.finalizeRecord(raw: raw, cleaned: cleaned, audioURL: settings.keepAudioFiles ? uploadURL : nil, source: "openai")
                            if !settings.keepAudioFiles {
                                try? FileManager.default.removeItem(at: audioURL)
                                if uploadURL != audioURL { try? FileManager.default.removeItem(at: uploadURL) }
                            } else if uploadURL != audioURL {
                                // Prefer keeping the compressed file; remove raw to save space
                                try? FileManager.default.removeItem(at: audioURL)
                            }
                            let total = Date().timeIntervalSince(pipelineStart)
                            NSLog("Pipeline: Total duration %.2fs", total)
                            self.previewVC.showFinalText(cleaned)
                        }
                    case .failure(let error):
                        let details = (error as NSError).localizedDescription
                        DispatchQueue.main.async {
                            let msg = "Cleanup failed. Copied transcribed text."
                            self.previewVC.setErrorDetails(details)
                            self.previewVC.setState(.error(msg))
                            self.finalizeRecord(raw: raw, cleaned: raw, audioURL: settings.keepAudioFiles ? uploadURL : nil, source: "error", resetUI: false)
                            let alert = NSAlert()
                            alert.messageText = "Cleanup Failed"
                            alert.informativeText = details
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                            self.previewVC.showFinalText(raw)
                            self.previewVC.setState(.idle)
                            self.setRecordingIcon(false)
                            if !settings.keepAudioFiles {
                                try? FileManager.default.removeItem(at: audioURL)
                                if uploadURL != audioURL { try? FileManager.default.removeItem(at: uploadURL) }
                            } else if uploadURL != audioURL {
                                try? FileManager.default.removeItem(at: audioURL)
                            }
                            let total = Date().timeIntervalSince(pipelineStart)
                            NSLog("Pipeline: Total duration %.2fs", total)
                        }
                    }
                } else {
                    // No cleanup: finalize with transcribed text
                    DispatchQueue.main.async {
                        self.finalizeRecord(raw: raw, cleaned: raw, audioURL: settings.keepAudioFiles ? uploadURL : nil, source: "openai")
                        if !settings.keepAudioFiles {
                            try? FileManager.default.removeItem(at: audioURL)
                            if uploadURL != audioURL { try? FileManager.default.removeItem(at: uploadURL) }
                        } else if uploadURL != audioURL {
                            try? FileManager.default.removeItem(at: audioURL)
                        }
                        let total = Date().timeIntervalSince(pipelineStart)
                        NSLog("Pipeline: Total duration %.2fs", total)
                        self.previewVC.showFinalText(raw)
                    }
                }
            }
        }
    }

    // Convert recorded audio to m4a (AAC) for OpenAI API compatibility/size.
    private func prepareAudioForUploadDetailed(originalURL: URL) -> (URL?, String?) {
        let ext = originalURL.pathExtension.lowercased()
        if ext == "m4a" { return (originalURL, nil) }
        let outURL = originalURL.deletingPathExtension().appendingPathExtension("m4a")
        try? FileManager.default.removeItem(at: outURL)
        let asset = AVURLAsset(url: originalURL)
        let duration = CMTimeGetSeconds(asset.duration)
        NSLog("Pipeline: Source audio duration %.2fs", duration)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            let details = "AVAssetExportSession unavailable for file: \(originalURL.lastPathComponent)"
            NSLog("Pipeline: \(details)")
            return (nil, details)
        }
        export.outputURL = outURL
        export.outputFileType = .m4a
        let sem = DispatchSemaphore(value: 0)
        export.exportAsynchronously { sem.signal() }
        sem.wait()
        switch export.status {
        case .completed:
            NSLog("Pipeline: Exported m4a -> \(outURL.lastPathComponent)")
            return (outURL, nil)
        case .failed, .cancelled:
            let err = export.error as NSError?
            let underlying = (err?.userInfo[NSUnderlyingErrorKey] as? NSError)?.localizedDescription
            let reason = err?.localizedFailureReason
            let suggestion = err?.localizedRecoverySuggestion
            let errDetails = [
                "status=\(export.status.rawValue)",
                err?.localizedDescription,
                reason,
                suggestion,
                underlying
            ].compactMap { $0 }.joined(separator: " | ")
            NSLog("Pipeline: m4a export failed: \(errDetails)")
            return (nil, errDetails.isEmpty ? "Unknown export error" : errDetails)
        default:
            return (nil, "Export ended with status=\(export.status.rawValue)")
        }
    }

    // High compression AAC encoder to reduce upload size for speech (mono, ~48kbps, 22.05kHz)
    private func encodeToM4ALowBitrate(originalURL: URL, sampleRate: Double = 22050, bitrate: Int = 48000) -> (URL?, String?) {
        if originalURL.pathExtension.lowercased() == "m4a" { return (originalURL, nil) }
        let asset = AVAsset(url: originalURL)
        guard let track = asset.tracks(withMediaType: .audio).first else {
            return (nil, "No audio track in asset")
        }
        let readerSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsNonInterleaved: false
        ]
        let writerSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: bitrate
        ]
        let outURL = originalURL.deletingPathExtension().appendingPathExtension("m4a")
        try? FileManager.default.removeItem(at: outURL)
        do {
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: readerSettings)
            if reader.canAdd(output) { reader.add(output) } else { return (nil, "Cannot add reader output") }
            let writer = try AVAssetWriter(outputURL: outURL, fileType: .m4a)
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: writerSettings)
            input.expectsMediaDataInRealTime = false
            if writer.canAdd(input) { writer.add(input) } else { return (nil, "Cannot add writer input") }
            guard writer.startWriting() else { return (nil, writer.error?.localizedDescription ?? "Writer start failed") }
            guard reader.startReading() else { return (nil, reader.error?.localizedDescription ?? "Reader start failed") }
            writer.startSession(atSourceTime: .zero)
            let queue = DispatchQueue(label: "encode.m4a.lowbitrate")
            let sem = DispatchSemaphore(value: 0)
            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData {
                    if let sample = output.copyNextSampleBuffer() {
                        if !input.append(sample) {
                            reader.cancelReading(); input.markAsFinished(); sem.signal(); return
                        }
                    } else {
                        input.markAsFinished(); sem.signal(); break
                    }
                }
            }
            sem.wait()
            writer.finishWriting {}
            if writer.status == .completed { return (outURL, nil) }
            let err = writer.error?.localizedDescription ?? reader.error?.localizedDescription ?? "Unknown encode error"
            return (nil, err)
        } catch {
            return (nil, error.localizedDescription)
        }
    }
    private func prepareAudioForUpload(originalURL: URL) -> URL? {
        let ext = originalURL.pathExtension.lowercased()
        if ext == "m4a" { return originalURL }
        let outURL = originalURL.deletingPathExtension().appendingPathExtension("m4a")
        try? FileManager.default.removeItem(at: outURL)
        let asset = AVURLAsset(url: originalURL)
        let duration = CMTimeGetSeconds(asset.duration)
        NSLog("Pipeline: Source audio duration %.2fs", duration)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            NSLog("Pipeline: AVAssetExportSession not available for \(originalURL.lastPathComponent)")
            return nil
        }
        export.outputURL = outURL
        export.outputFileType = .m4a
        let sem = DispatchSemaphore(value: 0)
        export.exportAsynchronously {
            sem.signal()
        }
        sem.wait()
        switch export.status {
        case .completed:
            NSLog("Pipeline: Exported m4a -> \(outURL.lastPathComponent)")
            return outURL
        case .failed, .cancelled:
            NSLog("Pipeline: m4a export failed: \(export.error?.localizedDescription ?? "unknown error")")
            return nil
        default:
            return nil
        }
    }

    private func finalizeRecord(raw: String, cleaned: String, audioURL: URL?, source: String, resetUI: Bool = true) {
        let trimmedRaw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClean = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRaw.isEmpty || !trimmedClean.isEmpty {
            let record = TranscriptionRecord(rawText: trimmedRaw, cleanedText: trimmedClean, audioFilePath: audioURL?.path, previewText: previewVC.currentText, source: source)
            try? historyStore.append(record)
            // Copy cleaned (or raw) text to clipboard after processing
            let textToCopy = trimmedClean.isEmpty ? trimmedRaw : trimmedClean
            if !textToCopy.isEmpty {
                NSLog("Pipeline: Copying \(textToCopy.count) chars to clipboard (source=\(source))")
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(textToCopy, forType: .string)
            }
        }
        if resetUI {
            previewVC.reset()
            previewVC.setState(.idle)
            setRecordingIcon(false)
        }
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

    private var historyWC: HistoryWindowController?
    @objc private func openHistory() {
        if historyWC == nil { historyWC = HistoryWindowController(historyStore: historyStore) }
        historyWC?.show()
    }

    @objc private func openBenchmark() {
        if benchmarkWC == nil { benchmarkWC = BenchmarkWindowController(settingsStore: settingsStore) }
        benchmarkWC?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func setRecordingIcon(_ recording: Bool) {
        guard let button = statusItem.button else { return }
        if recording {
            if let img = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "WhisperPaste Recording") {
                img.isTemplate = true
                button.image = img
            } else { button.title = "●" }
        } else {
            if let img = Self.loadStatusIcon() {
                img.isTemplate = true
                button.image = img
            } else if let sf = NSImage(systemSymbolName: "waveform", accessibilityDescription: "WhisperPaste") {
                sf.isTemplate = true; button.image = sf
            } else { button.title = "WP" }
        }
    }

    private static func loadStatusIcon() -> NSImage? {
        // Highest priority: explicit dev-run path
        let env = ProcessInfo.processInfo.environment
        // Support both 1x and 2x paths for crisper dev icon rendering
        let path1x = env["WP_STATUS_ICON_PATH_1X"] ?? env["WP_STATUS_ICON_PATH"]
        let path2x = env["WP_STATUS_ICON_PATH_2X"]
        if let p1 = path1x, !p1.isEmpty, FileManager.default.fileExists(atPath: p1) {
            if let p2 = path2x, !p2.isEmpty, FileManager.default.fileExists(atPath: p2) {
                // Combine 1x and 2x reps into a single NSImage
                let size = NSSize(width: 18, height: 18)
                let combined = NSImage(size: size)
                if let img1 = NSImage(contentsOfFile: p1), let rep1 = img1.representations.first {
                    rep1.size = size
                    combined.addRepresentation(rep1)
                }
                if let img2 = NSImage(contentsOfFile: p2), let rep2 = img2.representations.first {
                    rep2.size = size
                    combined.addRepresentation(rep2)
                }
                combined.isTemplate = true
                return combined
            } else if let img = NSImage(contentsOfFile: p1) {
                img.isTemplate = true
                return img
            }
        }
        if let named = NSImage(named: "statusIconTemplate") { return named }
        if let path = Bundle.main.path(forResource: "statusIconTemplate", ofType: "png") {
            return NSImage(contentsOfFile: path)
        }
        // Dev-run fallback: try project icon.png (repo root) when running via swift run
        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath // usually App/ when using scripts/run.sh
        let candidate = URL(fileURLWithPath: cwd).deletingLastPathComponent().appendingPathComponent("icon.png").path
        if fm.fileExists(atPath: candidate), let img = NSImage(contentsOfFile: candidate) {
            img.isTemplate = true // draw as monochrome in status bar
            // Scale to ~18pt for status item
            img.size = NSSize(width: 18, height: 18)
            return img
        }
        return nil
    }

    private func registerHotkey(from string: String) {
        let hk = Hotkey.parse(string)
        hotkeyManager.register(hotkey: hk) { [weak self] in
            DispatchQueue.main.async { self?.toggleRecording() }
        }
    }

    private func installEventMonitors() {
        if eventMonitor == nil {
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.maybeClosePopoverOnOutsideClick(event: event)
            }
        }
        if localEventMonitor == nil {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.maybeClosePopoverOnOutsideClick(event: event)
                return event
            }
        }
    }

    private func maybeClosePopoverOnOutsideClick(event: NSEvent?) {
        guard popover.isShown else { return }
        // If the click is on the status item button, do not close; we'll toggle state instead
        if let e = event, let button = statusItem.button, let win = button.window {
            let buttonRectInScreen = win.convertToScreen(button.bounds)
            // For global monitors, locationInWindow is in screen coords when event.window is nil
            let pointInScreen = (e.window != nil) ? win.convertToScreen(NSRect(origin: e.locationInWindow, size: .zero)).origin : e.locationInWindow
            if buttonRectInScreen.contains(pointInScreen) { return }
        }
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
