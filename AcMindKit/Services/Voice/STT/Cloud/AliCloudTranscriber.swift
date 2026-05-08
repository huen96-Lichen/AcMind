import Foundation

// MARK: - AliCloud Transcriber

/// 阿里云 DashScope Paraformer 实时语音识别
/// 文档：https://help.aliyun.com/zh/model-studio/developer-reference/paraformer-real-time-recognition
///
/// 使用 DashScope Paraformer WebSocket API 进行实时语音识别
/// token 参数为 DashScope API Key
public final class AliCloudTranscriber: Transcriber, @unchecked Sendable {

    private let appId: String
    private let token: String
    private var webSocketTask: URLSessionWebSocketTask?

    private let webSocketURL = "wss://dashscope.aliyuncs.com/api-ws/v1/inference"

    /// 音频分片大小 (16KB)
    private let chunkSize = 16 * 1024

    public init(appId: String, token: String) {
        self.appId = appId
        self.token = token
    }

    // MARK: - Transcriber Protocol

    public func transcribe(audioFile: AudioFile) async throws -> String {
        let audioData = try Data(contentsOf: audioFile.url)
        return try await runSession(audioData: audioData) { _ in }
    }

    public func transcribeStream(
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String {
        let audioData = try Data(contentsOf: audioFile.url)
        return try await runSession(audioData: audioData, onUpdate: onUpdate)
    }

    // MARK: - Core Session

    private func runSession(
        audioData: Data,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String {
        let taskId = UUID().uuidString
        var collectedText = ""

        // 1. 创建 WebSocket 连接
        guard let url = URL(string: webSocketURL) else {
            throw STTError.transcriptionFailed("无效的 WebSocket URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let session = URLSession(configuration: .default)
        let wsTask = session.webSocketTask(with: request)
        self.webSocketTask = wsTask

        // 设置接收处理
        var isFinished = false

        func handleMessage(_ message: URLSessionWebSocketTask.Message) {
            switch message {
            case .string(let text):
                if let data = text.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let header = json["header"] as? [String: Any],
                   let event = header["event"] as? String {

                    switch event {
                    case "task-started":
                        // 任务已启动，开始发送音频
                        break

                    case "result-generated":
                        if let payload = json["payload"] as? [String: Any],
                           let output = payload["output"] as? [String: Any],
                           let sentence = output["sentence"] as? [String: Any],
                           let text = sentence["text"] as? String {
                            let sentenceEnd = sentence["sentence_end"] as? Bool ?? false
                            collectedText += text
                            Task {
                                await onUpdate(TranscriptionSnapshot(
                                    text: collectedText,
                                    isFinal: sentenceEnd
                                ))
                            }
                        }

                    case "task-finished":
                        isFinished = true

                    case "error":
                        if let payload = json["payload"] as? [String: Any],
                           let _ = payload["message"] as? String {
                            isFinished = true
                        }

                    default:
                        break
                    }
                }

            case .data(let data):
                // 忽略二进制消息
                _ = data

            @unknown default:
                break
            }
        }

        // 启动接收循环
        func startReceive() {
            wsTask.receive { result in
                switch result {
                case .success(let message):
                    handleMessage(message)
                    if !isFinished {
                        startReceive()
                    }
                case .failure(let error):
                    isFinished = true
                    print("[AliCloudASR] WebSocket receive error: \(error)")
                }
            }
        }

        // 2. 连接并启动
        wsTask.resume()
        startReceive()

        // 等待连接建立
        try? await Task.sleep(nanoseconds: 500_000_000)

        // 3. 发送 run-task 命令
        let runTask: [String: Any] = [
            "header": [
                "action": "run-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "task_group": "audio",
                "task": "asr",
                "function": "recognition",
                "model": "paraformer-realtime-v2",
                "parameters": [
                    "format": "pcm",
                    "sample_rate": 16000
                ],
                "input": [:]
            ]
        ]

        guard let runTaskData = try? JSONSerialization.data(withJSONObject: runTask),
              let runTaskJSON = String(data: runTaskData, encoding: .utf8) else {
            wsTask.cancel(with: .internalServerError, reason: nil)
            throw STTError.transcriptionFailed("构建 run-task 命令失败")
        }

        try await wsTask.send(.string(runTaskJSON))

        // 等待 task-started
        try? await Task.sleep(nanoseconds: 500_000_000)

        // 4. 分片发送音频数据
        var offset = 0
        while offset < audioData.count {
            let end = min(offset + chunkSize, audioData.count)
            let chunk = audioData[offset..<end]
            try await wsTask.send(.data(Data(chunk)))
            offset = end

            // 控制发送速率，模拟实时流
            try? await Task.sleep(nanoseconds: 40_000_000) // ~40ms per chunk
        }

        // 5. 发送 finish-task 命令
        let finishTask: [String: Any] = [
            "header": [
                "action": "finish-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "input": [:]
            ]
        ]

        guard let finishTaskData = try? JSONSerialization.data(withJSONObject: finishTask),
              let finishTaskJSON = String(data: finishTaskData, encoding: .utf8) else {
            wsTask.cancel(with: .internalServerError, reason: nil)
            throw STTError.transcriptionFailed("构建 finish-task 命令失败")
        }

        try await wsTask.send(.string(finishTaskJSON))

        // 6. 等待 task-finished (最多 30 秒)
        let timeout: UInt64 = 30_000_000_000
        let deadline = DispatchTime.now() + .nanoseconds(Int(timeout))
        while !isFinished && DispatchTime.now() < deadline {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        // 7. 清理
        wsTask.cancel(with: .normalClosure, reason: nil)
        self.webSocketTask = nil

        if collectedText.isEmpty {
            throw STTError.transcriptionFailed("未获取到转写结果")
        }

        return collectedText
    }

    // MARK: - Cleanup

    private func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    deinit {
        disconnect()
    }
}
