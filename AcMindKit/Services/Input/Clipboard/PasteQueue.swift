import Foundation

public final class PasteQueue: @unchecked Sendable {
    
    public struct QueueItem: Sendable, Identifiable {
        public let id: String
        public let clipboardItemId: String
        public let addedAt: Date
        
        public init(clipboardItemId: String) {
            self.id = UUID().uuidString
            self.clipboardItemId = clipboardItemId
            self.addedAt = Date()
        }
    }
    
    private var queue: [QueueItem] = []
    private let lock = NSLock()
    
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return queue.count
    }
    
    public var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return queue.isEmpty
    }
    
    public var items: [QueueItem] {
        lock.lock()
        defer { lock.unlock() }
        return queue
    }
    
    public init() {}
    
    public func enqueue(clipboardItemId: String) {
        lock.lock()
        defer { lock.unlock() }
        let item = QueueItem(clipboardItemId: clipboardItemId)
        queue.append(item)
    }
    
    public func enqueueBatch(clipboardItemIds: [String]) {
        lock.lock()
        defer { lock.unlock() }
        for id in clipboardItemIds {
            queue.append(QueueItem(clipboardItemId: id))
        }
    }
    
    public func dequeue() -> QueueItem? {
        lock.lock()
        defer { lock.unlock() }
        guard !queue.isEmpty else { return nil }
        return queue.removeFirst()
    }
    
    public func peek() -> QueueItem? {
        lock.lock()
        defer { lock.unlock() }
        return queue.first
    }
    
    public func remove(id: String) {
        lock.lock()
        defer { lock.unlock() }
        queue.removeAll { $0.id == id }
    }
    
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        queue.removeAll()
    }
    
    public func moveItem(from sourceIndex: Int, to destinationIndex: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard sourceIndex >= 0, sourceIndex < queue.count,
              destinationIndex >= 0, destinationIndex < queue.count else { return }
        let item = queue.remove(at: sourceIndex)
        queue.insert(item, at: destinationIndex)
    }
}
