import Foundation

// MARK: - OpenAI Compatible Provider

/// OpenAI 兼容 Provider
/// 支持：
/// 1. OpenAI API
/// 2. Azure OpenAI
/// 3. 其他兼容 API (如 Claude, DeepSeek 等)
public final class OpenAICompatibleProvider: AIProvider {
    
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession
    private let timeout: TimeInterval
    private let defaultHeaders: [String: String]
    
    public init(
        baseURL: String,
        apiKey: String = "",
        timeout: TimeInterval = 120.0,
        defaultHeaders: [String: String] = [:]
    ) {
        self.baseURL = URL(string: baseURL) ?? URL(fileURLWithPath: "/")
        self.apiKey = apiKey
        self.timeout = timeout
        self.defaultHeaders = defaultHeaders
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Chat
    
    public func chat(messages: [ChatMessage], config: ChatConfig) async throws -> ChatResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = timeout
        
        // 添加自定义 headers
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        var body: [String: Any] = [
            "model": config.model ?? "gpt-3.5-turbo",
            "messages": messages.map { message in
                ["role": message.role, "content": message.content]
            }
        ]
        
        // 添加可选参数
        if let temperature = config.temperature {
            body["temperature"] = temperature
        }
        if let maxTokens = config.maxTokens {
            body["max_tokens"] = maxTokens
        }
        if let topP = config.topP {
            body["top_p"] = topP
        }
        if config.stream {
            body["stream"] = true
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        // 检查 HTTP 状态
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = parseErrorMessage(data: data) ?? "Unknown error"
            throw AIError.requestFailed("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        // 解析响应
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }
        
        let model = json["model"] as? String ?? config.model ?? "unknown"
        let usage = parseUsage(json: json)
        
        return ChatResponse(
            content: content,
            model: model,
            usage: usage
        )
    }
    
    // MARK: - Chat Stream
    
    public func chatStream(messages: [ChatMessage], config: ChatConfig) -> AsyncThrowingStream<ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: baseURL.appendingPathComponent("/v1/chat/completions"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    if !apiKey.isEmpty {
                        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    }
                    
                    for (key, value) in defaultHeaders {
                        request.setValue(value, forHTTPHeaderField: key)
                    }
                    
                    let body: [String: Any] = [
                        "model": config.model ?? "gpt-3.5-turbo",
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
                        "stream": true
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    
                    let (bytes, _) = try await session.bytes(for: request)
                    
                    for try await line in bytes.lines {
                        // OpenAI 流式格式: "data: {...}"
                        guard line.hasPrefix("data: ") else { continue }
                        
                        let jsonString = String(line.dropFirst(6))
                        if jsonString == "[DONE]" {
                            break
                        }
                        
                        guard let data = jsonString.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let firstChoice = choices.first,
                              let delta = firstChoice["delta"] as? [String: Any],
                              let content = delta["content"] as? String,
                              !content.isEmpty else {
                            continue
                        }
                        
                        let response = ChatResponse(
                            content: content,
                            model: json["model"] as? String,
                            isStreaming: true
                        )
                        continuation.yield(response)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - List Models
    
    public func listModels() async throws -> [String] {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/models"))
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.requestFailed("Failed to list models")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["data"] as? [[String: Any]] else {
            return []
        }
        
        return models.compactMap { $0["id"] as? String }
    }
    
    // MARK: - Health Check
    
    public func healthCheck() async throws -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/models"))
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }
    
    // MARK: - Helpers
    
    private func parseErrorMessage(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any] else {
            return nil
        }
        return error["message"] as? String ?? error["type"] as? String
    }
    
    private func parseUsage(json: [String: Any]) -> ChatUsage? {
        guard let usage = json["usage"] as? [String: Any] else { return nil }
        return ChatUsage(
            promptTokens: usage["prompt_tokens"] as? Int ?? 0,
            completionTokens: usage["completion_tokens"] as? Int ?? 0,
            totalDuration: nil
        )
    }
}
