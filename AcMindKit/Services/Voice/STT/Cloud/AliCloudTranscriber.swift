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
    private let hotwords: [String]
    private var webSocketTask: URLSessionWebSocketTask?

    private let webSocketURL = "wss://dashscope.aliyuncs.com/api-ws/v1/inference"

    /// 音频分片大小 (16KB)
    private let chunkSize = 16 * 1024

    public init(appId: String, token: String, hotwords: [String] = []) {
        self.appId = appId
        self.token = token
        self.hotwords = hotwords
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

            // 控制发送速率，分片推送音频，避免一次性突发发送
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

    public func createRealtimeSession() -> RealtimeTranscriptionSession? {
        AliCloudRealtimeSession(
            appId: appId,
            token: token,
            hotwords: hotwords
        )
    }

    deinit {
        disconnect()
    }
}

// MARK: - AliCloud Realtime Session

public actor AliCloudRealtimeSession: RealtimeTranscriptionSession {
    nonisolated(unsafe) public var onUpdate: (@Sendable (TranscriptionSnapshot) -> Void)?

    private let appId: String
    private let token: String
    private let hotwords: [String]
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false
    private var isTaskStarted = false
    private var isFinished = false
    private var accumulatedText = ""
    private let webSocketURL = "wss://dashscope.aliyuncs.com/api-ws/v1/inference"

    private var taskStartContinuation: CheckedContinuation<Void, Error>?

    init(appId: String, token: String, hotwords: [String]) {
        self.appId = appId
        self.token = token
        self.hotwords = hotwords
    }

    public func sendAudioData(_ data: Data) async throws {
        if !isConnected {
            try await connect()
        }
        guard let wsTask = webSocketTask else {
            throw STTError.transcriptionFailed("WebSocket 未连接")
        }
        try await wsTask.send(.data(data))
    }

    public func finish() async throws -> String {
        guard let wsTask = webSocketTask else {
            return accumulatedText
        }

        let finishTask: [String: Any] = [
            "header": [
                "action": "finish-task",
                "task_id": UUID().uuidString,
                "streaming": "duplex"
            ],
            "payload": [
                "input": [:]
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: finishTask),
              let json = String(data: data, encoding: .utf8) else {
            throw STTError.transcriptionFailed("构建 finish-task 命令失败")
        }

        try await wsTask.send(.string(json))

        let timeout: UInt64 = 30_000_000_000
        let deadline = DispatchTime.now() + .nanoseconds(Int(timeout))
        while !isFinished && DispatchTime.now() < deadline {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        wsTask.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false

        return accumulatedText
    }

    public func cancel() async {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        isFinished = true
    }

    private func connect() async throws {
        guard let url = URL(string: webSocketURL) else {
            throw STTError.transcriptionFailed("无效的 WebSocket URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let session = URLSession(configuration: .default)
        let wsTask = session.webSocketTask(with: request)
        self.webSocketTask = wsTask

        wsTask.resume()
        isConnected = true

        startReceiveLoop()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task { await self.beginTaskStart(continuation: continuation, wsTask: wsTask) }
        }
    }

    private func beginTaskStart(continuation: CheckedContinuation<Void, Error>, wsTask: URLSessionWebSocketTask) async {
        self.taskStartContinuation = continuation
        self.sendRunTaskCommand(wsTask: wsTask)
    }

    private func sendRunTaskCommand(wsTask: URLSessionWebSocketTask) {
        var parameters: [String: Any] = [
            "format": "pcm",
            "sample_rate": 16000
        ]

        if !hotwords.isEmpty {
            parameters["vocabulary"] = hotwords.joined(separator: ",")
        }

        let runTask: [String: Any] = [
            "header": [
                "action": "run-task",
                "task_id": UUID().uuidString,
                "streaming": "duplex"
            ],
            "payload": [
                "task_group": "audio",
                "task": "asr",
                "function": "recognition",
                "model": "paraformer-realtime-v2",
                "parameters": parameters,
                "input": [:]
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: runTask),
              let json = String(data: data, encoding: .utf8) else {
            taskStartContinuation?.resume(throwing: STTError.transcriptionFailed("构建 run-task 命令失败"))
            taskStartContinuation = nil
            return
        }

        Task {
            do {
                try await wsTask.send(.string(json))
            } catch {
                await self.resumeTaskStartContinuation(throwing: error)
            }
        }
    }

    private func resumeTaskStartContinuation(throwing error: Error) async {
        taskStartContinuation?.resume(throwing: error)
        taskStartContinuation = nil
    }

    private func startReceiveLoop() {
        guard let wsTask = webSocketTask else { return }

        wsTask.receive { [weak self] result in
            guard let self else { return }

            Task { await self.handleReceiveResult(result) }
        }
    }

    private func handleReceiveResult(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        switch result {
        case .success(let message):
            handleMessage(message)
            if !isFinished {
                startReceiveLoop()
            }
        case .failure:
            isFinished = true
            taskStartContinuation?.resume(throwing: STTError.transcriptionFailed("WebSocket 接收错误"))
            taskStartContinuation = nil
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let header = json["header"] as? [String: Any],
                  let event = header["event"] as? String else {
                return
            }

            switch event {
            case "task-started":
                isTaskStarted = true
                taskStartContinuation?.resume()
                taskStartContinuation = nil

            case "result-generated":
                if let payload = json["payload"] as? [String: Any],
                   let output = payload["output"] as? [String: Any],
                   let sentence = output["sentence"] as? [String: Any],
                   let text = sentence["text"] as? String {
                    let sentenceEnd = sentence["sentence_end"] as? Bool ?? false
                    accumulatedText += text
                    onUpdate?(TranscriptionSnapshot(
                        text: accumulatedText,
                        isFinal: sentenceEnd
                    ))
                }

            case "task-finished":
                isFinished = true

            case "error":
                isFinished = true
                let errorMessage = (json["payload"] as? [String: Any])?["message"] as? String ?? "未知错误"
                print("[AliCloudRealtimeSession] ASR error: \(errorMessage)")

            default:
                break
            }

        case .data:
            break

        @unknown default:
            break
        }
    }
}
