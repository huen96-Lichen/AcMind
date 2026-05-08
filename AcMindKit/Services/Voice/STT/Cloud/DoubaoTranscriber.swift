import Foundation

// MARK: - Doubao Transcriber

/// 火山引擎语音识别 (HTTP POST 方式)
/// 文档：https://www.volcengine.com/docs/6561/79817
///
/// 使用 HTTP POST 方式上传音频文件进行转写
/// WebSocket 协议较复杂，此处采用文件上传 API 作为简化实现
public final class DoubaoTranscriber: Transcriber {

    private let appId: String
    private let token: String

    private let apiURL = "https://openspeech.bytedance.com/api/v1/asr"

    public init(appId: String, token: String) {
        self.appId = appId
        self.token = token
    }

    // MARK: - Transcriber Protocol

    public func transcribe(audioFile: AudioFile) async throws -> String {
        let audioData = try Data(contentsOf: audioFile.url)

        guard let url = URL(string: apiURL) else {
            throw STTError.transcriptionFailed("无效的 API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(appId, forHTTPHeaderField: "appid")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw STTError.transcriptionFailed("无效的服务器响应")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "未知错误"
            throw STTError.transcriptionFailed(
                "HTTP \(httpResponse.statusCode): \(body)"
            )
        }

        // 解析 JSON 响应
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw STTError.transcriptionFailed("无法解析响应 JSON")
        }

        // 尝试常见响应格式
        // 格式1: { "result": "转写文本" }
        if let result = json["result"] as? String {
            return result
        }

        // 格式2: { "data": { "result": "转写文本" } }
        if let dataDict = json["data"] as? [String: Any],
           let result = dataDict["result"] as? String {
            return result
        }

        // 格式3: { "payload": { "output": { "text": "..." } } }
        if let payload = json["payload"] as? [String: Any],
           let output = payload["output"] as? [String: Any],
           let text = output["text"] as? String {
            return text
        }

        // 格式4: { "text": "转写文本" }
        if let text = json["text"] as? String {
            return text
        }

        throw STTError.transcriptionFailed("响应中未找到转写结果: \(json)")
    }

    public func transcribeStream(
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String {
        // HTTP POST 方式不支持流式，使用默认实现：转写完成后发送最终快照
        let text = try await transcribe(audioFile: audioFile)
        await onUpdate(TranscriptionSnapshot(text: text, isFinal: true))
        return text
    }
}
