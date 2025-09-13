import XCTest
@testable import WhisperpasteCore
import Foundation

final class OpenAIClientTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        StubURLProtocol.requestHandler = nil
    }

    func makeClient(_ handler: @escaping (URLRequest) -> (Int, Data?, [String: String]?)) -> OpenAIClient {
        StubURLProtocol.requestHandler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        return OpenAIClient(session: session)
    }

    func testTranscribeParsesTextOn200() throws {
        let client = makeClient { req in
            XCTAssertEqual(req.url?.path, "/v1/audio/transcriptions")
            let body = ["text": "hello world"]
            let data = try! JSONSerialization.data(withJSONObject: body, options: [])
            return (200, data, ["Content-Type": "application/json"])
        }
        // The file won't actually be read because the stub intercepts the request; create a temp placeholder path.
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.wav")
        FileManager.default.createFile(atPath: tmp.path, contents: Data(), attributes: nil)
        let text = try client.transcribe(apiKey: "sk-test", audioFileURL: tmp, model: "whisper-1", prompt: nil)
        XCTAssertEqual(text, "hello world")
    }

    func testTranscribeHttpErrorSurfaced() throws {
        let client = makeClient { _ in
            let body = ["error": ["message": "Invalid audio"]]
            let data = try! JSONSerialization.data(withJSONObject: body, options: [])
            return (400, data, ["Content-Type": "application/json"])
        }
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bad.wav")
        FileManager.default.createFile(atPath: tmp.path, contents: Data(), attributes: nil)
        do {
            _ = try client.transcribe(apiKey: "sk-test", audioFileURL: tmp, model: "whisper-1", prompt: nil)
            XCTFail("Expected error")
        } catch let error as OpenAIClient.ClientError {
            switch error {
            case .http(let code, let message):
                XCTAssertEqual(code, 400)
                XCTAssertEqual(message, "Invalid audio")
            default:
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testCleanupParsesChatCompletion() throws {
        let client = makeClient { _ in
            let body: [String: Any] = [
                "choices": [["message": ["content": "Cleaned text."]]]
            ]
            let data = try! JSONSerialization.data(withJSONObject: body, options: [])
            return (200, data, ["Content-Type": "application/json"])
        }
        let cleaned = try client.cleanup(apiKey: "sk-test", text: "raw", prompt: "fix", model: "gpt-4o-mini")
        XCTAssertEqual(cleaned, "Cleaned text.")
    }

    func testListModelsParsesAndSorts() throws {
        let client = makeClient { _ in
            let body: [String: Any] = [
                "data": [["id": "gpt-4o"], ["id": "whisper-1"], ["id": "gpt-4o-mini"]]
            ]
            let data = try! JSONSerialization.data(withJSONObject: body, options: [])
            return (200, data, ["Content-Type": "application/json"])
        }
        let models = try client.listModels(apiKey: "sk-test")
        XCTAssertEqual(models, ["gpt-4o", "gpt-4o-mini", "whisper-1"]) // sorted
    }
}

// MARK: - URLProtocol stub
final class StubURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) -> (Int, Data?, [String: String]?))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = StubURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "Stub", code: -1))
            return
        }
        let (status, data, headers) = handler(request)
        let url = request.url ?? URL(string: "https://example.invalid")!
        let resp = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        if let d = data { client?.urlProtocol(self, didLoad: d) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { /* no-op */ }
}

