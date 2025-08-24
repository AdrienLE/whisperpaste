import Foundation

public struct OpenAIModels {
    public static let defaultTranscription = "whisper-1" // or gpt-4o-mini-transcribe
    public static let defaultCleanup = "gpt-4o-mini"
}

public protocol TranscriptionService {
    func transcribe(apiKey: String, audioFileURL: URL, model: String) throws -> String
}

public protocol CleanupService {
    func cleanup(apiKey: String, text: String, prompt: String, model: String) throws -> String
}

public final class OpenAIClient: TranscriptionService, CleanupService {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public enum ClientError: Error { case invalidResponse, http(Int), noData }

    public func transcribe(apiKey: String, audioFileURL: URL, model: String) throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = try Self.multipartBody(boundary: boundary, params: ["model": model], fileURL: audioFileURL, fileParam: "file", filename: audioFileURL.lastPathComponent, mime: "audio/x-caf")
        let (data, resp) = try syncRequest(req)
        guard let http = resp as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw ClientError.http(http.statusCode) }
        guard let data = data else { throw ClientError.noData }
        // Response: { text: "..." } for whisper endpoint
        let obj = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        let text = obj?["text"] as? String ?? ""
        return text
    }

    public func cleanup(apiKey: String, text: String, prompt: String, model: String) throws -> String {
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.2
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, resp) = try syncRequest(req)
        guard let http = resp as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw ClientError.http(http.statusCode) }
        guard let data = data else { throw ClientError.noData }
        let obj = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        if let choices = obj?["choices"] as? [[String: Any]],
           let msg = choices.first?["message"] as? [String: Any],
           let content = msg["content"] as? String {
            return content
        }
        return text
    }

    private func syncRequest(_ req: URLRequest) throws -> (Data?, URLResponse?) {
        var outData: Data?
        var outResp: URLResponse?
        var outErr: Error?
        let sem = DispatchSemaphore(value: 0)
        let task = session.dataTask(with: req) { data, resp, err in
            outData = data
            outResp = resp
            outErr = err
            sem.signal()
        }
        task.resume()
        sem.wait()
        if let e = outErr { throw e }
        return (outData, outResp)
    }

    private static func multipartBody(boundary: String, params: [String: String], fileURL: URL, fileParam: String, filename: String, mime: String) throws -> Data {
        var body = Data()
        func append(_ string: String) { body.append(string.data(using: .utf8)!) }
        for (k, v) in params {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(k)\"\r\n\r\n\(v)\r\n")
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(fileParam)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mime)\r\n\r\n")
        let fileData = try Data(contentsOf: fileURL)
        body.append(fileData)
        append("\r\n")
        append("--\(boundary)--\r\n")
        return body
    }
}
