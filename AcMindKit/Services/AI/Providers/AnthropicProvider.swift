import Foundation

public final class AnthropicProvider: AIProvider, @unchecked Sendable {
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession
    private let timeout: TimeInterval
    private let apiVersion: String

    public init(
        baseURL: String = ProviderType.anthropic.defaultBaseURL,
        apiKey: String,
        timeout: TimeInterval = 120.0,
        apiVersion: String = "2023-06-01",
        session: URLSession? = nil
    ) {
        self.baseURL = URL(string: baseURL)!
        self.apiKey = apiKey
        self.timeout = timeout
        self.apiVersion = apiVersion

        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = timeout
            config.timeoutIntervalForResource = timeout
            self.session = URLSession(configuration: config)
        }
    }

    public func chat(messages: [ChatMessage], config: ChatConfig) async throws -> ChatResponse {
        var request = URLRequest(url: endpoint("v1/messages"))
        request.httpMethod = "POST"
        applyHeaders(to: &request)
        request.timeoutInterval = timeout
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(messages: messages, config: config))

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try parseMessageResponse(data: data, fallbackModel: config.model)
    }

    public func chatStream(messages: [ChatMessage], config: ChatConfig) -> AsyncThrowingStream<ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var streamingConfig = config
                    streamingConfig.stream = true
                    var request = URLRequest(url: endpoint("v1/messages"))
                    request.httpMethod = "POST"
                    applyHeaders(to: &request)
                    request.timeoutInterval = timeout
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(messages: messages, config: streamingConfig))

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                        throw AIError.requestFailed("Anthropic stream request failed")
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        guard payload != "[DONE]",
                              let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let type = json["type"] as? String,
                              type == "content_block_delta",
                              let delta = json["delta"] as? [String: Any],
                              let text = delta["text"] as? String,
                              text.isEmpty == false else {
                            continue
                        }
                        continuation.yield(ChatResponse(content: text, model: streamingConfig.model, isStreaming: true))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func listModels() async throws -> [String] {
        var request = URLRequest(url: endpoint("v1/models"))
        applyHeaders(to: &request)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let data = json["data"] as? [[String: Any]] else {
            return []
        }
        return data.compactMap { $0["id"] as? String }
    }

    public func healthCheck() async throws -> Bool {
        (try? await listModels().isEmpty == false) ?? false
    }

    private func requestBody(messages: [ChatMessage], config: ChatConfig) -> [String: Any] {
        var body: [String: Any] = [
            "model": config.model ?? "claude-3-5-sonnet-latest",
            "max_tokens": config.maxTokens ?? 1024,
            "messages": messages
                .filter { $0.role != .system }
                .map { message in
                    [
                        "role": message.role == .assistant ? "assistant" : "user",
                        "content": message.content,
                    ]
                },
        ]

        let systemPrompt = messages
            .filter { $0.role == .system }
            .map(\.content)
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if systemPrompt.isEmpty == false {
            body["system"] = systemPrompt
        }
        if let temperature = config.temperature {
            body["temperature"] = temperature
        }
        if config.stream {
            body["stream"] = true
        }
        return body
    }

    private func parseMessageResponse(data: Data, fallbackModel: String?) throws -> ChatResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let blocks = json["content"] as? [[String: Any]] else {
            throw AIError.invalidResponse
        }

        let text = blocks.compactMap { block -> String? in
            guard (block["type"] as? String) == "text" else { return nil }
            return block["text"] as? String
        }.joined()

        let usagePayload = json["usage"] as? [String: Any]
        let usage = ChatUsage(
            promptTokens: usagePayload?["input_tokens"] as? Int ?? 0,
            completionTokens: usagePayload?["output_tokens"] as? Int ?? 0
        )

        return ChatResponse(
            content: text,
            model: json["model"] as? String ?? fallbackModel,
            finishReason: json["stop_reason"] as? String,
            usage: usage
        )
    }

    private func applyHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw AIError.requestFailed("HTTP \(http.statusCode): \(parseErrorMessage(data: data) ?? "Unknown error")")
        }
    }

    private func parseErrorMessage(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let error = json["error"] as? [String: Any] {
            return error["message"] as? String ?? error["type"] as? String
        }
        return json["message"] as? String
    }

    private func endpoint(_ path: String) -> URL {
        path.split(separator: "/").reduce(baseURL) { url, component in
            url.appendingPathComponent(String(component))
        }
    }
}
