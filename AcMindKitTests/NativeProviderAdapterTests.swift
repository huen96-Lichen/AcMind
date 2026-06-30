import XCTest
@testable import AcMindKit

final class NativeProviderAdapterTests: XCTestCase {
    override func tearDown() {
        ProviderURLProtocolStub.handler = nil
        super.tearDown()
    }

    func testAnthropicProviderUsesMessagesAPIAndParsesTextResponse() async throws {
        ProviderURLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/messages")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")

            let body = try XCTUnwrap(request.httpBodyStream.flatMap(Self.readStream))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["model"] as? String, "claude-test")
            XCTAssertEqual(json["system"] as? String, "Be concise.")

            let response = """
            {
              "id": "msg_1",
              "type": "message",
              "role": "assistant",
              "model": "claude-test",
              "stop_reason": "end_turn",
              "content": [{ "type": "text", "text": "Anthropic OK" }],
              "usage": { "input_tokens": 7, "output_tokens": 3 }
            }
            """
            return Self.response(request: request, body: response)
        }

        let provider = AnthropicProvider(
            baseURL: "https://anthropic.test",
            apiKey: "test-key",
            session: Self.stubbedSession()
        )
        let result = try await provider.chat(messages: [
            ChatMessage(sessionId: "s", role: .system, content: "Be concise."),
            ChatMessage(sessionId: "s", role: .user, content: "Ping"),
        ], config: ChatConfig(model: "claude-test"))

        XCTAssertEqual(result.content, "Anthropic OK")
        XCTAssertEqual(result.model, "claude-test")
        XCTAssertEqual(result.usage?.promptTokens, 7)
        XCTAssertEqual(result.usage?.completionTokens, 3)
    }

    func testGoogleProviderUsesGenerateContentAPIAndParsesTextResponse() async throws {
        ProviderURLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1beta/models/gemini-test:generateContent")
            XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "key" })?.value, "test-key")

            let body = try XCTUnwrap(request.httpBodyStream.flatMap(Self.readStream))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertNotNil(json["systemInstruction"])
            XCTAssertNotNil(json["contents"])

            let response = """
            {
              "candidates": [{
                "content": { "parts": [{ "text": "Gemini OK" }], "role": "model" },
                "finishReason": "STOP"
              }],
              "usageMetadata": {
                "promptTokenCount": 5,
                "candidatesTokenCount": 2
              }
            }
            """
            return Self.response(request: request, body: response)
        }

        let provider = GoogleGenerativeAIProvider(
            baseURL: "https://google.test",
            apiKey: "test-key",
            session: Self.stubbedSession()
        )
        let result = try await provider.chat(messages: [
            ChatMessage(sessionId: "s", role: .system, content: "Be concise."),
            ChatMessage(sessionId: "s", role: .user, content: "Ping"),
        ], config: ChatConfig(model: "gemini-test"))

        XCTAssertEqual(result.content, "Gemini OK")
        XCTAssertEqual(result.model, "gemini-test")
        XCTAssertEqual(result.usage?.promptTokens, 5)
        XCTAssertEqual(result.usage?.completionTokens, 2)
    }

    private static func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ProviderURLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private static func response(request: URLRequest, body: String, statusCode: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(body.utf8))
    }

    private static func readStream(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read > 0 {
                data.append(buffer, count: read)
            } else {
                break
            }
        }
        return data
    }
}

private final class ProviderURLProtocolStub: URLProtocol, @unchecked Sendable {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
