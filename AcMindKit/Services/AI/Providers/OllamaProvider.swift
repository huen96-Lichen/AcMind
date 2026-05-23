import Foundation

// MARK: - Ollama Provider

/// Ollama 本地模型 Provider
/// 支持：
/// 1. Chat 对话
/// 2. 流式输出
/// 3. 模型列表
/// 4. 健康检查
public final class OllamaProvider: AIProvider {
    
    private let baseURL: URL
    private let session: URLSession
    private let timeout: TimeInterval
    
    public init(
        baseURL: String = "http://localhost:11434",
        timeout: TimeInterval = 120.0
    ) {
        self.baseURL = URL(string: baseURL) ?? URL(fileURLWithPath: "/")
        self.timeout = timeout
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Chat
    
    public func chat(messages: [ChatMessage], config: ChatConfig) async throws -> ChatResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        
        var body: [String: Any] = [
            "model": config.model ?? "llama2",
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": false
        ]
        
        // 添加可选参数
        if let temperature = config.temperature {
            body["options"] = ["temperature": temperature]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        // 检查 HTTP 状态
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.requestFailed("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        // 解析响应
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }
        
        let model = json["model"] as? String ?? config.model ?? "unknown"
        let totalDuration = json["total_duration"] as? Int64
        
        return ChatResponse(
            content: content,
            model: model,
            usage: totalDuration.map { ChatUsage(promptTokens: 0, completionTokens: 0, totalDuration: $0) }
        )
    }
    
    // MARK: - Chat Stream
    
    public func chatStream(messages: [ChatMessage], config: ChatConfig) -> AsyncThrowingStream<ChatResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: baseURL.appendingPathComponent("/api/chat"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    let body: [String: Any] = [
                        "model": config.model ?? "llama2",
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
                        "stream": true
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    
                    let (bytes, _) = try await session.bytes(for: request)
                    
                    var buffer = Data()
                    for try await byte in bytes {
                        buffer.append(byte)
                        
                        // 检查是否是完整的 JSON 行
                        if let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                            let lineData = buffer[..<newlineIndex]
                            buffer = buffer[buffer.index(after: newlineIndex)...]
                            
                            if let line = String(data: lineData, encoding: .utf8),
                               let lineData = line.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                               let message = json["message"] as? [String: Any],
                               let content = message["content"] as? String,
                               !content.isEmpty {
                                
                                let response = ChatResponse(
                                    content: content,
                                    model: json["model"] as? String,
                                    isStreaming: true
                                )
                                continuation.yield(response)
                            }
                        }
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
        let request = URLRequest(url: baseURL.appendingPathComponent("/api/tags"))
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.requestFailed("Failed to list models")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            return []
        }
        
        return models.compactMap { $0["name"] as? String }
    }
    
    // MARK: - Health Check
    
    public func healthCheck() async throws -> Bool {
        let request = URLRequest(url: baseURL.appendingPathComponent("/api/tags"))
        
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
    
    // MARK: - Pull Model
    
    public func pullModel(name: String) async throws -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/pull"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["name": name])
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        return httpResponse.statusCode == 200
    }
}
