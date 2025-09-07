import Foundation
import AVFoundation
import Speech
import WhisperpasteCore

final class SpeechRecorder {
    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
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
        self.recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        accumulatedPreview = ""
        NSLog("SpeechRecorder: start() invoked")

        // Request permissions
        SFSpeechRecognizer.requestAuthorization { [weak self] auth in
            guard let self = self else { return }
            NSLog("SpeechRecorder: speech auth status=\(auth.rawValue)")
            guard auth == .authorized else {
                self.finishWithError(NSError(domain: "SpeechRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"]))
                return
            }
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                NSLog("SpeechRecorder: mic access granted=\(granted)")
                guard granted else {
                    self.finishWithError(NSError(domain: "SpeechRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Microphone access denied"]))
                    return
                }
                DispatchQueue.main.async { self.configureAndStart() }
            }
        }
    }

    private func configureAndStart() {
        NSLog("SpeechRecorder: configureAndStart() begin")
        // Prepare audio file path
        do {
            let audioDir = try AppSupportPaths.audioDirectory()
            // Write uncompressed WAV during recording for reliability; compress to m4a post-stop.
            let name = "rec-" + ISO8601DateFormatter().string(from: Date()) + ".wav"
            let url = audioDir.appendingPathComponent(name)
            audioURL = url
            NSLog("SpeechRecorder: will write WAV to \(url.lastPathComponent)")
        } catch {
            NSLog("SpeechRecorder: failed to create audio path: \(error.localizedDescription)")
            onError?(error)
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        // Recognition request
        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true
        request?.requiresOnDeviceRecognition = false
        request?.taskHint = .dictation

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
                    NSLog("SpeechRecorder: recognition error=\(error.localizedDescription)")
                    self.finishWithError(error)
                }
                // Do not auto-stop here; stopping is user-controlled.
            }
        } else {
            NSLog("SpeechRecorder: recognizer unavailable or request missing")
            onPreview?("Live preview unavailable for current locale")
        }

        // File for writing
        if let audioURL = audioURL {
            do {
                audioFile = try AVAudioFile(forWriting: audioURL, settings: format.settings)
            } catch {
                NSLog("SpeechRecorder: AVAudioFile open failed: \(error.localizedDescription)")
                onError?(error)
            }
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
        do {
            try engine.start()
            NSLog("SpeechRecorder: engine started")
        } catch {
            NSLog("SpeechRecorder: engine start failed: \(error.localizedDescription)")
            finishWithError(error)
        }
    }

    func stop() {
        guard isRunning else { return }
        NSLog("SpeechRecorder: stop() invoked")
        isRunning = false
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        // Give recognizer a short moment to deliver final results
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            self.engine.stop()
            self.engine.reset()
            self.task?.cancel()
            self.task = nil
            self.request = nil
            let url = self.audioURL
            self.audioFile = nil
            DispatchQueue.main.async {
                NSLog("SpeechRecorder: finished, url=\(url?.lastPathComponent ?? "nil")")
                self.onFinish?(url)
            }
        }
    }

    private func finishWithError(_ error: Error) {
        onError?(error)
        stop()
    }

    // Accessors
    var previewText: String { accumulatedPreview }
    var recordedFileURL: URL? { audioURL }
}
