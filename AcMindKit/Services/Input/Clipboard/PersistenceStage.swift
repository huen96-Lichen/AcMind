import Foundation

public struct PersistenceStage: PipelineStage {
    private let storage: StorageServiceProtocol

    public init(storage: StorageServiceProtocol) {
        self.storage = storage
    }

    public func process(_ context: inout PipelineContext) async throws {
        guard let item = context.item, !context.shouldIgnore else { return }
        try await storage.insertClipboardItem(item)
    }
}
