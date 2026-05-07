import Foundation

// MARK: - Task Queue

/// 任务队列服务
/// 功能：
/// 1. 任务入队 (enqueue)
/// 2. 任务列表 (list)
/// 3. 任务取消 (cancel)
/// 4. 状态更新 (status update)
/// 5. 任务执行 (自动/手动)
public actor TaskQueue {
    
    // MARK: - Properties
    
    private var jobs: [String: ProcessJob] = [:]
    private var queue: [String] = []
    private var running: Set<String> = []
    private var maxConcurrent: Int = 2
    private var isProcessing = false
    
    // MARK: - Callbacks
    
    private var onJobStatusChanged: ((ProcessJob) -> Void)?
    
    // MARK: - Initialization
    
    public init(maxConcurrent: Int = 2) {
        self.maxConcurrent = maxConcurrent
    }
    
    // MARK: - Set Callback
    
    public func setOnJobStatusChanged(_ handler: @escaping (ProcessJob) -> Void) {
        self.onJobStatusChanged = handler
    }
    
    // MARK: - Enqueue
    
    public func enqueue(_ job: ProcessJob) -> String {
        var newJob = job
        newJob.status = .queued
        
        jobs[job.id] = newJob
        queue.append(job.id)
        
        // 触发处理
        Task {
            await processQueue()
        }
        
        return job.id
    }
    
    public func enqueueBatch(_ jobList: [ProcessJob]) -> [String] {
        var ids: [String] = []
        
        for var job in jobList {
            job.status = .queued
            jobs[job.id] = job
            queue.append(job.id)
            ids.append(job.id)
        }
        
        // 触发处理
        Task {
            await processQueue()
        }
        
        return ids
    }
    
    // MARK: - List
    
    public func list() -> [ProcessJob] {
        Array(jobs.values).sorted { $0.createdAt > $1.createdAt }
    }
    
    public func list(status: ProcessJobStatus) -> [ProcessJob] {
        jobs.values.filter { $0.status == status }.sorted { $0.createdAt > $1.createdAt }
    }
    
    public func get(id: String) -> ProcessJob? {
        jobs[id]
    }
    
    // MARK: - Cancel
    
    public func cancel(id: String) throws {
        guard var job = jobs[id] else {
            throw TaskQueueError.jobNotFound
        }
        
        guard job.status == .queued || job.status == .running else {
            throw TaskQueueError.cannotCancel(job.status)
        }
        
        job.status = .cancelled
        job.finishedAt = Date()
        jobs[id] = job
        
        // 从队列中移除
        queue.removeAll { $0 == id }
        running.remove(id)
        
        notifyStatusChanged(job)
    }
    
    public func cancelAll() {
        for id in queue {
            if var job = jobs[id] {
                job.status = .cancelled
                job.finishedAt = Date()
                jobs[id] = job
                notifyStatusChanged(job)
            }
        }
        
        queue.removeAll()
        
        for id in running {
            if var job = jobs[id] {
                job.status = .cancelled
                job.finishedAt = Date()
                jobs[id] = job
                notifyStatusChanged(job)
            }
        }
        
        running.removeAll()
    }
    
    // MARK: - Status Update
    
    public func updateStatus(id: String, status: ProcessJobStatus) throws {
        guard var job = jobs[id] else {
            throw TaskQueueError.jobNotFound
        }
        
        job.status = status
        
        if status == .succeeded || status == .failed || status == .cancelled {
            job.finishedAt = Date()
            running.remove(id)
        }
        
        if status == .running {
            running.insert(id)
        }
        
        jobs[id] = job
        notifyStatusChanged(job)
        
        // 继续处理队列
        Task {
            await processQueue()
        }
    }
    
    public func updateProgress(id: String, progress: Double) throws {
        guard var job = jobs[id] else {
            throw TaskQueueError.jobNotFound
        }
        
        job.progress = progress
        jobs[id] = job
        notifyStatusChanged(job)
    }
    
    public func updateResult(id: String, result: String) throws {
        guard var job = jobs[id] else {
            throw TaskQueueError.jobNotFound
        }
        
        job.result = result
        jobs[id] = job
    }
    
    public func updateError(id: String, error: String) throws {
        guard var job = jobs[id] else {
            throw TaskQueueError.jobNotFound
        }
        
        job.error = error
        job.status = .failed
        job.finishedAt = Date()
        jobs[id] = job
        running.remove(id)
        
        notifyStatusChanged(job)
        
        Task {
            await processQueue()
        }
    }
    
    // MARK: - Process Queue
    
    private func processQueue() async {
        guard !isProcessing else { return }
        isProcessing = true
        
        defer { isProcessing = false }
        
        while running.count < maxConcurrent && !queue.isEmpty {
            let jobId = queue.removeFirst()
            
            guard var job = jobs[jobId] else { continue }
            
            // 检查是否已取消
            if job.status == .cancelled { continue }
            
            // 标记为运行中
            job.status = .running
            job.startedAt = Date()
            jobs[jobId] = job
            running.insert(jobId)
            
            notifyStatusChanged(job)
        }
    }
    
    // MARK: - Retry
    
    public func retry(id: String) throws {
        guard var job = jobs[id] else {
            throw TaskQueueError.jobNotFound
        }
        
        guard job.status == .failed || job.status == .cancelled else {
            throw TaskQueueError.cannotRetry(job.status)
        }
        
        job.status = .queued
        job.error = nil
        job.progress = 0
        job.startedAt = nil
        job.finishedAt = nil
        jobs[id] = job
        queue.append(id)
        
        notifyStatusChanged(job)
        
        Task {
            await processQueue()
        }
    }
    
    // MARK: - Clear
    
    public func clearCompleted() {
        let completedIds = jobs.filter { 
            $0.value.status == .succeeded || $0.value.status == .failed || $0.value.status == .cancelled
        }.keys
        
        for id in completedIds {
            jobs.removeValue(forKey: id)
        }
    }
    
    // MARK: - Stats
    
    public func stats() -> TaskQueueStats {
        let all = Array(jobs.values)
        return TaskQueueStats(
            total: all.count,
            queued: all.filter { $0.status == .queued }.count,
            running: all.filter { $0.status == .running }.count,
            completed: all.filter { $0.status == .succeeded }.count,
            failed: all.filter { $0.status == .failed }.count,
            cancelled: all.filter { $0.status == .cancelled }.count
        )
    }
    
    // MARK: - Private
    
    private func notifyStatusChanged(_ job: ProcessJob) {
        onJobStatusChanged?(job)
    }
}

// MARK: - Stats

public struct TaskQueueStats: Sendable, Equatable {
    public let total: Int
    public let queued: Int
    public let running: Int
    public let completed: Int
    public let failed: Int
    public let cancelled: Int
    
    public init(
        total: Int = 0,
        queued: Int = 0,
        running: Int = 0,
        completed: Int = 0,
        failed: Int = 0,
        cancelled: Int = 0
    ) {
        self.total = total
        self.queued = queued
        self.running = running
        self.completed = completed
        self.failed = failed
        self.cancelled = cancelled
    }
}

// MARK: - Errors

public enum TaskQueueError: Error, LocalizedError {
    case jobNotFound
    case cannotCancel(ProcessJobStatus)
    case cannotRetry(ProcessJobStatus)
    case queueFull
    
    public var errorDescription: String? {
        switch self {
        case .jobNotFound:
            return "任务未找到"
        case .cannotCancel(let status):
            return "无法取消状态为 \(status.displayName) 的任务"
        case .cannotRetry(let status):
            return "无法重试状态为 \(status.displayName) 的任务"
        case .queueFull:
            return "任务队列已满"
        }
    }
}
