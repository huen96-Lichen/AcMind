import Foundation

// MARK: - MiMo ASR Transcriber

/// 小米 MiMo ASR 语音识别
/// API 文档: https://platform.xiaomimimo.com/docs/zh-CN/usage-guide/Speech-Recognition
public final class MiMoTranscriber: Transcriber {
    
    private let apiKey: String
    private let baseURL: String
    private let model: String
    private let language: String
    
    public init(
        apiKey: String,
        baseURL: String = "https://api.xiaomimimo.com/v1",
        model: String = "mimo-v2.5-asr",
        language: String = "auto"
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.language = language
    }
    
    public func transcribe(audioFile: AudioFile) async throws -> String {
        let audioData = try Data(contentsOf: audioFile.url)
        let audioBase64 = audioData.base64EncodedString()
        
        let mimeType = mimeTypeForFile(audioFile.url)
        let dataURL = "data:\(mimeType);base64,\(audioBase64)"
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_audio",
                            "input_audio": [
                                "data": dataURL
                            ]
                        ]
                    ]
                ]
            ],
            "asr_options": [
                "language": language
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw STTError.transcriptionFailed("无效响应")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            throw STTError.transcriptionFailed("MiMo ASR 错误 (\(httpResponse.statusCode)): \(errorMessage)")
        }
        
        guard let result = try? JSONDecoder().decode(MiMoResponse.self, from: data),
              let content = result.choices.first?.message.content else {
            throw STTError.transcriptionFailed("无法解析 MiMo ASR 响应")
        }
        
        return content
    }
    
    // MARK: - Private
    
    private func mimeTypeForFile(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "wav": return "audio/wav"
        case "mp3": return "audio/mpeg"
        default: return "audio/wav"
        }
    }
}

// MARK: - Response Models

private struct MiMoResponse: Decodable {
    let choices: [Choice]
    
    struct Choice: Decodable {
        let message: Message
    }
    
    struct Message: Decodable {
        let content: String
    }
}
