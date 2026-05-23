import Foundation

// MARK: - OpenAI Whisper Transcriber

/// OpenAI Whisper API 转写器
public final class OpenAIWhisperTranscriber: Transcriber {
    
    private let apiKey: String
    private let baseURL: String
    private let model: String
    
    public init(
        apiKey: String,
        baseURL: String = "https://api.openai.com/v1",
        model: String = "whisper-1"
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
    }
    
    public func transcribe(audioFile: AudioFile) async throws -> String {
        let audioData = try Data(contentsOf: audioFile.url)
        
        guard let url = URL(string: "\(baseURL)/audio/transcriptions") else {
            throw STTError.transcriptionFailed("无效转写地址")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // 构建 multipart/form-data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        func append(_ string: String) {
            body.append(string.data(using: .utf8) ?? Data())
        }
        
        // 文件数据
        let fileName = audioFile.url.lastPathComponent
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: audio/mpeg\r\n\r\n")
        body.append(audioData)
        append("\r\n")
        
        // model 参数
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        append(model)
        append("\r\n")
        
        // language 参数（可选）
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
        append("zh")
        append("\r\n")
        
        // response_format 参数
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
        append("json")
        append("\r\n")
        
        append("--\(boundary)--\r\n")
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw STTError.transcriptionFailed("无效响应")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            throw STTError.transcriptionFailed("API 错误 (\(httpResponse.statusCode)): \(errorMessage)")
        }
        
        // 解析响应
        struct TranscriptionResponse: Decodable {
            let text: String
        }
        
        guard let result = try? JSONDecoder().decode(TranscriptionResponse.self, from: data) else {
            throw STTError.transcriptionFailed("无法解析响应")
        }
        
        return result.text
    }
}
