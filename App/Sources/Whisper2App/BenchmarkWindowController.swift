import AppKit
import AVFoundation
import Whisper2Core

final class BenchmarkWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    struct Result {
        enum Stage: String {
            case transcribe = "Transcribe"
            case cleanup = "Cleanup"
        }
        let stage: Stage
        let model: String
        let duration: TimeInterval
        let error: String?
    }

    private let table = NSTableView()
    private let scroll = NSScrollView()
    private let recordButton = NSButton(title: "Record Sample", target: nil, action: nil)
    private let stopButton = NSButton(title: "Stop", target: nil, action: nil)
    private let runButton = NSButton(title: "Run Benchmark", target: nil, action: nil)
    private let testAllCheckbox = NSButton(checkboxWithTitle: "Test all models", target: nil, action: nil)
    private let infoLabel = NSTextField(labelWithString: "Record a short sample, then run the benchmark.")

    private var results: [Result] = []
    private var recorder: SpeechRecorder?
    private var sampleURL: URL?
    private let settingsStore: SettingsStore
    private let historyStore = HistoryStore()

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 420),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Benchmark Models"
        super.init(window: window)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupUI() {
        guard let content = window?.contentView else { return }
        let stageCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("stage")); stageCol.title = "Stage"; stageCol.width = 120
        let modelCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("model")); modelCol.title = "Model"; modelCol.width = 280
        let timeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time")); timeCol.title = "Seconds"; timeCol.width = 100
        let errorCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("error")); errorCol.title = "Error"; errorCol.width = 300
        // Enable sorting
        stageCol.sortDescriptorPrototype = NSSortDescriptor(key: "stage", ascending: true)
        modelCol.sortDescriptorPrototype = NSSortDescriptor(key: "model", ascending: true)
        timeCol.sortDescriptorPrototype = NSSortDescriptor(key: "time", ascending: true)
        table.addTableColumn(stageCol); table.addTableColumn(modelCol); table.addTableColumn(timeCol); table.addTableColumn(errorCol)
        table.dataSource = self; table.delegate = self
        scroll.documentView = table; scroll.hasVerticalScroller = true; scroll.translatesAutoresizingMaskIntoConstraints = false

        recordButton.target = self; recordButton.action = #selector(startRecord)
        stopButton.target = self; stopButton.action = #selector(stopRecord); stopButton.isEnabled = false
        runButton.target = self; runButton.action = #selector(runBenchmark)
        infoLabel.lineBreakMode = .byWordWrapping

        let controls = NSStackView(views: [recordButton, stopButton, testAllCheckbox, NSView(), runButton])
        controls.orientation = .horizontal; controls.alignment = .centerY; controls.spacing = 8; controls.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(controls); content.addSubview(scroll); content.addSubview(infoLabel)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controls.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            controls.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            controls.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            infoLabel.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 6),
            infoLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            infoLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            scroll.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10)
        ])
    }

    @objc private func startRecord() {
        recorder = SpeechRecorder(historyStore: historyStore, settingsStore: settingsStore)
        recordButton.isEnabled = false; stopButton.isEnabled = true
        results.removeAll(); table.reloadData()
        infoLabel.stringValue = "Recording… speak for a few seconds, then Stop."
        recorder?.onFinish = { [weak self] url in
            DispatchQueue.main.async { self?.handleRecorded(url: url) }
        }
        recorder?.start()
    }

    private func handleRecorded(url: URL?) {
        stopButton.isEnabled = false; recordButton.isEnabled = true
        if let url = url { sampleURL = url; infoLabel.stringValue = "Sample saved: \(url.lastPathComponent)" }
        else { infoLabel.stringValue = "No sample recorded." }
    }

    @objc private func stopRecord() { recorder?.stop() }

    @objc private func runBenchmark() {
        guard let apiKey = settingsStore.load().openAIKey, !apiKey.isEmpty else { NSSound.beep(); infoLabel.stringValue = "Set API key in Settings."; return }
        guard let sample = sampleURL, FileManager.default.fileExists(atPath: sample.path) else { NSSound.beep(); infoLabel.stringValue = "Record a sample first."; return }
        let s = settingsStore.load()
        var transModels = s.knownTranscriptionModels ?? [Settings(openAIKey: nil).transcriptionModel]
        var cleanModels = s.knownCleanupModels ?? [Settings(openAIKey: nil).cleanupModel]
        let includeAll = (testAllCheckbox.state == .on)
        transModels = SettingsWindowController.filteredModels(transModels, includeAll: includeAll || s.showAllModels)
        cleanModels = SettingsWindowController.filteredModels(cleanModels, includeAll: includeAll || s.showAllModels)
        // Extra cleanup eligibility filter to avoid non-chat/audio-only models
        let cleanupExcludedKeywords = ["audio", "tts", "realtime", "embed", "transcribe", "whisper"]
        cleanModels = cleanModels.filter { id in !cleanupExcludedKeywords.contains { id.localizedCaseInsensitiveContains($0) } }
        results.removeAll(); table.reloadData(); infoLabel.stringValue = "Running benchmark…"
        let client = OpenAIClient()

        // Convert sample to m4a for consistent benchmarking
        let (m4aURL, convErr) = convertToM4A(sample)
        let uploadURL = m4aURL ?? sample
        if let e = convErr { DispatchQueue.main.async { self.infoLabel.stringValue = "Using WAV (conversion failed): \(e)" } }

        DispatchQueue.global(qos: .userInitiated).async {
            // Transcription timings
            var referenceText: String? = nil
            for m in transModels {
                let t0 = Date()
                do {
                    let txt = try client.transcribe(apiKey: apiKey, audioFileURL: uploadURL, model: m)
                    let dt = Date().timeIntervalSince(t0)
                    self.append(.init(stage: .transcribe, model: m, duration: dt, error: nil))
                    if referenceText == nil { referenceText = txt }
                } catch {
                    let dt = Date().timeIntervalSince(t0)
                    self.append(.init(stage: .transcribe, model: m, duration: dt, error: error.localizedDescription))
                }
            }
            // Cleanup timings
            let text = referenceText ?? "This is a sample for cleanup benchmark."
            for m in cleanModels {
                let t0 = Date()
                do {
                    _ = try client.cleanup(apiKey: apiKey, text: text, prompt: s.cleanupPrompt, model: m)
                    let dt = Date().timeIntervalSince(t0)
                    self.append(.init(stage: .cleanup, model: m, duration: dt, error: nil))
                } catch {
                    let dt = Date().timeIntervalSince(t0)
                    self.append(.init(stage: .cleanup, model: m, duration: dt, error: error.localizedDescription))
                }
            }
            DispatchQueue.main.async { self.infoLabel.stringValue = "Benchmark complete." }
        }
    }

    private func append(_ r: Result) {
        DispatchQueue.main.async {
            self.results.append(r)
            self.applySort()
            self.table.reloadData()
        }
    }

    private func applySort() {
        guard let sort = table.sortDescriptors.first else { return }
        let ascending = sort.ascending
        switch sort.key {
        case "time":
            results.sort { ascending ? $0.duration < $1.duration : $0.duration > $1.duration }
        case "model":
            results.sort { ascending ? $0.model.localizedCaseInsensitiveCompare($1.model) == .orderedAscending : $0.model.localizedCaseInsensitiveCompare($1.model) == .orderedDescending }
        case "stage":
            results.sort { ascending ? $0.stage.rawValue < $1.stage.rawValue : $0.stage.rawValue > $1.stage.rawValue }
        default:
            break
        }
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        applySort(); tableView.reloadData()
    }

    // Convert sample to m4a for upload
    private func convertToM4A(_ url: URL) -> (URL?, String?) {
        if url.pathExtension.lowercased() == "m4a" { return (url, nil) }
        let asset = AVAsset(url: url)
        guard let track = asset.tracks(withMediaType: .audio).first else { return (nil, "No audio track") }
        let out = url.deletingPathExtension().appendingPathExtension("m4a")
        try? FileManager.default.removeItem(at: out)
        let readerSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsNonInterleaved: false
        ]
        let writerSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 22050,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 48000
        ]
        do {
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: readerSettings)
            if reader.canAdd(output) { reader.add(output) } else { return (nil, "Cannot add reader output") }
            let writer = try AVAssetWriter(outputURL: out, fileType: .m4a)
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: writerSettings)
            if writer.canAdd(input) { writer.add(input) } else { return (nil, "Cannot add writer input") }
            guard writer.startWriting() else { return (nil, writer.error?.localizedDescription ?? "Writer start failed") }
            guard reader.startReading() else { return (nil, reader.error?.localizedDescription ?? "Reader start failed") }
            writer.startSession(atSourceTime: .zero)
            let sem = DispatchSemaphore(value: 0)
            let q = DispatchQueue(label: "benchmark.encode.m4a")
            input.requestMediaDataWhenReady(on: q) {
                while input.isReadyForMoreMediaData {
                    if let sample = output.copyNextSampleBuffer() {
                        if !input.append(sample) { reader.cancelReading(); input.markAsFinished(); sem.signal(); return }
                    } else { input.markAsFinished(); sem.signal(); break }
                }
            }
            sem.wait(); writer.finishWriting {}
            return writer.status == .completed ? (out, nil) : (nil, writer.error?.localizedDescription ?? reader.error?.localizedDescription ?? "Unknown encode error")
        } catch { return (nil, error.localizedDescription) }
    }

    // MARK: - Table
    func numberOfRows(in tableView: NSTableView) -> Int { results.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let r = results[row]
        let id = tableColumn?.identifier.rawValue
        let text: String
        switch id {
        case "stage": text = r.stage.rawValue
        case "model": text = r.model
        case "time": text = String(format: "%.2f", r.duration)
        case "error": text = r.error ?? ""
        default: text = ""
        }
        let cell = NSTableCellView(); let label = NSTextField(labelWithString: text)
        label.lineBreakMode = .byTruncatingMiddle; label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }
}
