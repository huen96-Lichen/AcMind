import Foundation

public final class ClipboardPipeline: @unchecked Sendable {
    public let discovery: DiscoveryStage
    public let transformation: TransformationStage
    public let validation: ValidationStage
    public let persistence: PersistenceStage
    public let distribution: DistributionStage

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
        try await discovery.process(&context)
        guard !context.shouldIgnore else { return }

        try await transformation.process(&context)
        guard !context.shouldIgnore else { return }

        try await validation.process(&context)
        guard !context.shouldIgnore else { return }

        try await persistence.process(&context)
        try await distribution.process(&context)
    }
}
