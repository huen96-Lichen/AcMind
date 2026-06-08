import Foundation
import AVFoundation
import Accelerate

// MARK: - Silence Detection Service

/// 静音检测服务
/// 职责：
/// 1. 监控音频输入能量
/// 2. 检测静音状态
/// 3. 基于 ASR 的静音检测
/// 4. 支持可配置的静音阈值和超时
public actor SilenceDetectionService {
    
    // MARK: - Singleton
    
    public static let shared = SilenceDetectionService()
    
    // MARK: - Properties
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var isMonitoring = false
    private var currentEnergy: Float = 0.0
    private var lastSpeechTime: Date?
    private var silenceStartTime: Date?
    private var bufferCounter: Int = 0
    private let bufferSamplingInterval: Int = 3
    
    // MARK: - Configuration
    
    private var silenceThreshold: Float = -30.0 // 分贝阈值
    private var silenceTimeout: TimeInterval = 3.0 // 静音超时（秒）
    private var speechResetTimeout: TimeInterval = 0.5 // 语音重置超时
    
    // MARK: - Callbacks
    
    private var onSilenceDetected: (() -> Void)?
    private var onSpeechDetected: (() -> Void)?
    private var onEnergyChanged: ((Float) -> Void)?
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// 开始监控音频能量
    public func startMonitoring(
        silenceThreshold: Float = -30.0,
        silenceTimeout: TimeInterval = 3.0,
        onSilenceDetected: @escaping @Sendable () -> Void,
        onSpeechDetected: @escaping @Sendable () -> Void,
        onEnergyChanged: @escaping @Sendable (Float) -> Void
    ) async throws {
        guard !isMonitoring else { return }
        
        self.silenceThreshold = silenceThreshold
        self.silenceTimeout = silenceTimeout
        self.onSilenceDetected = onSilenceDetected
        self.onSpeechDetected = onSpeechDetected
        self.onEnergyChanged = onEnergyChanged
        
        try setupAudioEngine()
        isMonitoring = true
        lastSpeechTime = Date()
        silenceStartTime = nil
    }
    
    /// 停止监控
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        isMonitoring = false
        currentEnergy = 0.0
        lastSpeechTime = nil
        silenceStartTime = nil
    }
    
    /// 获取当前音频能量
    public func getCurrentEnergy() -> Float {
        return currentEnergy
    }
    
    /// 检查是否正在监控
    public func isCurrentlyMonitoring() -> Bool {
        return isMonitoring
    }
    
    /// 更新静音阈值
    public func updateSilenceThreshold(_ threshold: Float) {
        self.silenceThreshold = threshold
    }
    
    /// 更新静音超时
    public func updateSilenceTimeout(_ timeout: TimeInterval) {
        self.silenceTimeout = timeout
    }
    
    /// 重置检测状态
    public func resetDetectionState() {
        lastSpeechTime = Date()
        silenceStartTime = nil
    }
    
    public func resetSilenceTimer() {
        lastSpeechTime = Date()
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() throws {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        guard let inputNode = inputNode else {
            throw SilenceDetectionError.audioEngineSetupFailed
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // 安装 tap 来监控音频
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            Task { @MainActor in
                await self?.processAudioBuffer(buffer)
            }
        }
        
        try audioEngine?.start()
    }
    
    // MARK: - Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isMonitoring else { return }
        
        bufferCounter += 1
        guard bufferCounter % bufferSamplingInterval == 0 else { return }
        
        let energy = calculateAudioEnergy(buffer: buffer)
        currentEnergy = energy
        
        onEnergyChanged?(energy)
        
        let isSpeaking = energy > silenceThreshold
        
        if isSpeaking {
            handleSpeechDetected()
        } else {
            handleSilenceDetected()
        }
    }
    
    private func calculateAudioEnergy(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0.0 }
        let frames = Int(buffer.frameLength)
        var rms: Float = 0.0
        vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(frames))
        let db = 20 * log10(max(rms, 1e-10))
        return db
    }
    
    // MARK: - Speech Detection
    
    private func handleSpeechDetected() {
        let now = Date()
        
        // 如果之前是静音状态，触发语音检测回调
        if silenceStartTime != nil {
            silenceStartTime = nil
            onSpeechDetected?()
        }
        
        lastSpeechTime = now
    }
    
    private func handleSilenceDetected() {
        guard let lastSpeech = lastSpeechTime else { return }
        
        let now = Date()
        let silenceDuration = now.timeIntervalSince(lastSpeech)
        
        // 如果静音时间超过阈值
        if silenceDuration >= silenceTimeout {
            // 如果还没有开始静音计时，开始计时
            if silenceStartTime == nil {
                silenceStartTime = now
            }
            
            // 如果静音时间足够长，触发静音检测回调
            if let silenceStart = silenceStartTime,
               now.timeIntervalSince(silenceStart) >= speechResetTimeout {
                onSilenceDetected?()
                // 重置状态，避免重复触发
                lastSpeechTime = nil
                silenceStartTime = nil
            }
        }
    }
}

// MARK: - Silence Detection Error

public enum SilenceDetectionError: Error, LocalizedError {
    case audioEngineSetupFailed
    case microphonePermissionDenied
    case audioSessionSetupFailed
    
    public var errorDescription: String? {
        switch self {
        case .audioEngineSetupFailed:
            return "音频引擎设置失败"
        case .microphonePermissionDenied:
            return "麦克风权限被拒绝"
        case .audioSessionSetupFailed:
            return "音频会话设置失败"
        }
    }
}