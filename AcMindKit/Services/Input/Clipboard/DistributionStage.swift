import Foundation
import Combine

public final class DistributionStage: PipelineStage, @unchecked Sendable {
    public let itemCaptured = PassthroughSubject<ClipboardItem, Never>()

    public init() {}

    public func process(_ context: inout PipelineContext) async throws {
        guard let item = context.item, !context.shouldIgnore else { return }
        itemCaptured.send(item)
    }
}
