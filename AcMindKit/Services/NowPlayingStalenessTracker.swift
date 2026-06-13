import Foundation

public struct NowPlayingStalenessTracker: Sendable, Equatable {
    public var clearThreshold: Int
    public private(set) var consecutiveMisses: Int

    public init(clearThreshold: Int = 2) {
        self.clearThreshold = max(1, clearThreshold)
        self.consecutiveMisses = 0
    }

    public mutating func recordSourceFound() {
        consecutiveMisses = 0
    }

    /// Returns true when the caller should clear stale playback state.
    public mutating func recordSourceMissing() -> Bool {
        consecutiveMisses += 1
        return consecutiveMisses >= clearThreshold
    }

    public mutating func reset() {
        consecutiveMisses = 0
    }
}
