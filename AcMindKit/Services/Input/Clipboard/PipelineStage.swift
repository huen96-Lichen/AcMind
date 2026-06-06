import Foundation

public protocol PipelineStage: Sendable {
    func process(_ context: inout PipelineContext) async throws
}
