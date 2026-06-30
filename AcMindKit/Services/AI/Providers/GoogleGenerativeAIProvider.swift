import Foundation

public final class GoogleGenerativeAIProvider: AIProvider, @unchecked Sendable {
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession
    private let timeout: TimeInterval

    public init(
        baseURL: String = ProviderType.google.defaultBaseURL,
        apiKey: String,
        timeout: TimeInterval = 120.0,
        session: URLSession? = nil
    ) {
        self.baseURL = URL(string: baseURL)!
        self.apiKey = apiKey
        self.timeout = timeout

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
        let model = config.model ?? "gemini-1.5-flash"
        var request = URLRequest(url: endpoint("v1beta/models/\(model):generateContent", queryItems: [
            URLQueryItem(name: "key", value: apiKey)
        ]))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(messages: messages, config: config))

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try parseGenerateContentResponse(data: data, fallbackModel: model)
    }

    public func chatStream(messages: [ChatMessage], config: ChatConfig) -> AsyncThrowingStream<ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let model = config.model ?? "gemini-1.5-flash"
                    var request = URLRequest(url: endpoint("v1beta/models/\(model):streamGenerateContent", queryItems: [
                        URLQueryItem(name: "key", value: apiKey),
                        URLQueryItem(name: "alt", value: "sse"),
                    ]))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.timeoutInterval = timeout
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(messages: messages, config: config))

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                        throw AIError.requestFailed("Google Gemini stream request failed")
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        guard let data = payload.data(using: .utf8),
                              let chunk = try? parseGenerateContentResponse(data: data, fallbackModel: model),
                              chunk.content.isEmpty == false else {
                            continue
                        }
                        continuation.yield(ChatResponse(content: chunk.content, model: model, isStreaming: true))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func listModels() async throws -> [String] {
        var request = URLRequest(url: endpoint("v1beta/models", queryItems: [
            URLQueryItem(name: "key", value: apiKey)
        ]))
        request.timeoutInterval = timeout
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            return []
        }
        return models.compactMap { model in
            guard let name = model["name"] as? String else { return nil }
            return name.hasPrefix("models/") ? String(name.dropFirst("models/".count)) : name
        }
    }

    public func healthCheck() async throws -> Bool {
        (try? await listModels().isEmpty == false) ?? false
    }

    private func requestBody(messages: [ChatMessage], config: ChatConfig) -> [String: Any] {
        var body: [String: Any] = [
            "contents": messages
                .filter { $0.role != .system }
                .map { message in
                    [
                        "role": message.role == .assistant ? "model" : "user",
                        "parts": [["text": message.content]],
                    ]
                },
        ]

        let systemPrompt = messages
            .filter { $0.role == .system }
            .map(\.content)
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if systemPrompt.isEmpty == false {
            body["systemInstruction"] = ["parts": [["text": systemPrompt]]]
        }

        var generationConfig: [String: Any] = [:]
        if let temperature = config.temperature {
            generationConfig["temperature"] = temperature
        }
        if let maxTokens = config.maxTokens {
            generationConfig["maxOutputTokens"] = maxTokens
        }
        if let topP = config.topP {
            generationConfig["topP"] = topP
        }
        if generationConfig.isEmpty == false {
            body["generationConfig"] = generationConfig
        }

        return body
    }

    private func parseGenerateContentResponse(data: Data, fallbackModel: String?) throws -> ChatResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw AIError.invalidResponse
        }

        let text = parts.compactMap { $0["text"] as? String }.joined()
        let usagePayload = json["usageMetadata"] as? [String: Any]
        let usage = ChatUsage(
            promptTokens: usagePayload?["promptTokenCount"] as? Int ?? 0,
            completionTokens: usagePayload?["candidatesTokenCount"] as? Int ?? 0
        )

        return ChatResponse(
            content: text,
            model: fallbackModel,
            finishReason: first["finishReason"] as? String,
            usage: usage
        )
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
            return error["message"] as? String ?? error["status"] as? String
        }
        return json["message"] as? String
    }

    private func endpoint(_ path: String, queryItems: [URLQueryItem] = []) -> URL {
        let url = path.split(separator: "/").reduce(baseURL) { url, component in
            url.appendingPathComponent(String(component))
        }
        guard queryItems.isEmpty == false,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.queryItems = queryItems
        return components.url ?? url
    }
}
