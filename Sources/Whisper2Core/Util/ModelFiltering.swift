import Foundation

public enum ModelFiltering {
    // Partition a raw list of model ids into transcription-capable and chat-capable cleanup models.
    public static func partition(models: [String]) -> (transcription: [String], cleanup: [String]) {
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

    // Filter out preview/experimental/time-suffixed models unless includeAll == true
    public static func filtered(_ models: [String], includeAll: Bool) -> [String] {
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
}

