import Foundation
import AVFoundation
import Speech
import Whisper2Core

final class SpeechRecorder {
    private let engine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var audioFile: AVAudioFile?
    private var audioURL: URL?
    private var isRunning = false

    private let historyStore: HistoryStore
    private let settingsStore: SettingsStore

    // Callbacks
    var onPreview: ((String) -> Void)?
    var onError: ((Error) -> Void)?
    var onFinish: ((URL?) -> Void)?

    private var accumulatedPreview: String = ""

    init(historyStore: HistoryStore, settingsStore: SettingsStore) {
        self.historyStore = historyStore
        self.settingsStore = settingsStore
        self.recognizer = SFSpeechRecognizer(locale: Locale.current)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        accumulatedPreview = ""

        // Request permissions
        SFSpeechRecognizer.requestAuthorization { [weak self] auth in
            guard let self = self else { return }
            guard auth == .authorized else {
                self.finishWithError(NSError(domain: "SpeechRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"]))
                return
            }
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                guard granted else {
                    self.finishWithError(NSError(domain: "SpeechRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Microphone access denied"]))
                    return
                }
                DispatchQueue.main.async { self.configureAndStart() }
            }
        }
    }

    private func configureAndStart() {
        // Prepare audio file path
        do {
            let audioDir = try AppSupportPaths.audioDirectory()
            let name = "rec-" + ISO8601DateFormatter().string(from: Date()) + ".caf"
            let url = audioDir.appendingPathComponent(name)
            audioURL = url
        } catch {
            onError?(error)
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        // Recognition request
        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true

        // Recognition task
        if let recognizer = recognizer, recognizer.isAvailable, let request = request {
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }
                if let r = result {
                    let text = r.bestTranscription.formattedString
                    self.accumulatedPreview = text
                    self.onPreview?(text)
                }
                if let error = error {
                    self.finishWithError(error)
                }
                if result?.isFinal == true {
                    self.stop()
                }
            }
        }

        // File for writing
        if let audioURL = audioURL {
            do { audioFile = try AVAudioFile(forWriting: audioURL, settings: format.settings) }
            catch { onError?(error) }
        }

        // Install tap to capture mic
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.request?.append(buffer)
            if let file = self.audioFile {
                do { try file.write(from: buffer) } catch { /* ignore write errors */ }
            }
        }

        engine.prepare()
        do { try engine.start() } catch { finishWithError(error) }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        let url = audioURL
        audioFile = nil
        onFinish?(url)
    }

    private func finishWithError(_ error: Error) {
        onError?(error)
        stop()
    }

    // Accessors
    var previewText: String { accumulatedPreview }
    var recordedFileURL: URL? { audioURL }
}
