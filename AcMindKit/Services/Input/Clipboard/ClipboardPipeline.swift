import Foundation

public final class ClipboardPipeline: @unchecked Sendable {
    public let discovery: DiscoveryStage
    public let transformation: TransformationStage
    public let validation: ValidationStage
    public let persistence: PersistenceStage
    public let distribution: DistributionStage

    private let statusLock = NSLock()
    private var activeOperationID: UUID?
    private var status = InputChainStatusSnapshot(
        source: .clipboard,
        phase: .idle,
        stepLabel: "等待输入",
        detail: "等待剪贴板内容"
    )

    public init(
        assetStore: AssetStore,
        storage: StorageServiceProtocol,
        cleaningRulesEvaluator: (@Sendable (String, String?) -> ClipboardCleaningDecision)? = nil
    ) {
        self.discovery = DiscoveryStage(assetStore: assetStore)
        self.transformation = TransformationStage(cleaningRulesEvaluator: cleaningRulesEvaluator)
        self.validation = ValidationStage()
        self.persistence = PersistenceStage(storage: storage)
        self.distribution = DistributionStage()
    }

    public func process(_ context: inout PipelineContext) async throws {
        let operationID = UUID()
        updateStatus(
            operationID: operationID,
            phase: .processing,
            stepLabel: "内容发现",
            detail: "正在识别剪贴板内容"
        )

        do {
            try await discovery.process(&context)
            guard !context.shouldIgnore else {
                updateStatus(
                    operationID: operationID,
                    phase: .ignored,
                    stepLabel: "内容发现",
                    detail: "未发现可保存内容"
                )
                return
            }

            updateStatus(
                operationID: operationID,
                phase: .processing,
                stepLabel: "内容转换",
                detail: "正在清理并标记内容"
            )
            try await transformation.process(&context)
            guard !context.shouldIgnore else {
                updateStatus(
                    operationID: operationID,
                    phase: .ignored,
                    stepLabel: "内容转换",
                    detail: "内容已按清理规则忽略"
                )
                return
            }

            updateStatus(
                operationID: operationID,
                phase: .processing,
                stepLabel: "内容校验",
                detail: "正在检查重复与回写内容"
            )
            try await validation.process(&context)
            guard !context.shouldIgnore else {
                updateStatus(
                    operationID: operationID,
                    phase: .ignored,
                    stepLabel: "内容校验",
                    detail: "重复或回写内容已忽略"
                )
                return
            }

            updateStatus(
                operationID: operationID,
                phase: .processing,
                stepLabel: "持久化",
                detail: "正在保存剪贴板内容"
            )
            try await persistence.process(&context)

            updateStatus(
                operationID: operationID,
                phase: .processing,
                stepLabel: "内容分发",
                detail: "正在通知剪贴板订阅方"
            )
            try await distribution.process(&context)

            updateStatus(
                operationID: operationID,
                phase: .succeeded,
                stepLabel: "分发完成",
                detail: "剪贴板内容已入库并分发"
            )
        } catch {
            let currentStep = statusSnapshot().stepLabel
            updateStatus(
                operationID: operationID,
                phase: .failed,
                stepLabel: currentStep,
                detail: "剪贴板内容处理失败",
                nextActionTitle: "重试",
                lastErrorMessage: error.localizedDescription
            )
            throw error
        }
    }

    public func statusSnapshot() -> InputChainStatusSnapshot {
        statusLock.lock()
        defer { statusLock.unlock() }
        return status
    }

    private func updateStatus(
        operationID: UUID,
        phase: InputChainPhase,
        stepLabel: String,
        detail: String,
        nextActionTitle: String? = nil,
        lastErrorMessage: String? = nil
    ) {
        statusLock.lock()
        defer { statusLock.unlock() }

        if phase == .processing, activeOperationID == nil || stepLabel == "内容发现" {
            activeOperationID = operationID
        }
        guard activeOperationID == operationID else { return }

        status = InputChainStatusSnapshot(
            source: .clipboard,
            phase: phase,
            stepLabel: stepLabel,
            detail: detail,
            nextActionTitle: nextActionTitle,
            lastErrorMessage: lastErrorMessage
        )
    }
}
