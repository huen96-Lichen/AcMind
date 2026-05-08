import Foundation
@preconcurrency import Speech
import AVFoundation

// MARK: - Apple Speech Transcriber

/// Apple 系统语音识别
/// 使用 SFSpeechRecognizer 实现
public final class AppleSpeechTranscriber: Transcriber, @unchecked Sendable {
    
    private let speechRecognizer: SFSpeechRecognizer?
    
    public init(locale: Locale = Locale(identifier: "zh-CN")) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }
    
    public func transcribe(audioFile: AudioFile) async throws -> String {
        guard let recognizer = speechRecognizer else {
            throw STTError.providerNotAvailable("语音识别器不可用")
        }
        
        guard recognizer.isAvailable else {
            throw STTError.providerNotAvailable("语音识别服务不可用，请检查系统设置")
        }
        
        // 请求权限
        let authorized = await requestAuthorization()
        guard authorized else {
            throw STTError.providerNotAvailable("语音识别权限未授权")
        }
        
        // 创建识别请求
        let request = SFSpeechURLRecognitionRequest(url: audioFile.url)
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        
        // 执行识别
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: STTError.transcriptionFailed(error.localizedDescription))
                    return
                }
                
                guard let result = result else {
                    continuation.resume(throwing: STTError.transcriptionFailed("无识别结果"))
                    return
                }
                
                if result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
    
    public func transcribeStream(
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String {
        guard let recognizer = speechRecognizer else {
            throw STTError.providerNotAvailable("语音识别器不可用")
        }
        
        guard recognizer.isAvailable else {
            throw STTError.providerNotAvailable("语音识别服务不可用")
        }
        
        let authorized = await requestAuthorization()
        guard authorized else {
            throw STTError.providerNotAvailable("语音识别权限未授权")
        }
        
        let request = SFSpeechURLRecognitionRequest(url: audioFile.url)
        request.shouldReportPartialResults = true
        request.addsPunctuation = true

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: STTError.transcriptionFailed(error.localizedDescription))
                    return
                }
                
                guard let result = result else { return }
                
                let text = result.bestTranscription.formattedString
                // 发送更新
                Task {
                    await onUpdate(TranscriptionSnapshot(text: text, isFinal: result.isFinal))
                }
                
                if result.isFinal {
                    continuation.resume(returning: text)
                }
            }
        }
    }
    
    // MARK: - Authorization
    
    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
