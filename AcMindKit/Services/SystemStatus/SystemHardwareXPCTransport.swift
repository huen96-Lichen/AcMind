import Foundation

public final class SystemHardwareXPCTransport: SystemHardwareTransport {
    public let isAvailable: Bool

    private let serviceName: String
    private let timeout: TimeInterval
    private let connectionLock = NSLock()
    private var connection: NSXPCConnection?

    public init(serviceName: String, timeout: TimeInterval = 0.75) {
        self.serviceName = serviceName
        self.timeout = timeout
        self.isAvailable = Self.probe(serviceName: serviceName, timeout: timeout)
    }

    public func refreshFanControlStates() -> [SystemFanControlState] {
        guard let proxy = helperProxy() else { return [] }
        let semaphore = DispatchSemaphore(value: 0)
        var encodedStates: Data?

        proxy.refreshFanControlStates { data in
            encodedStates = data
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success else { return [] }
        guard let encodedStates else { return [] }
        return (try? JSONDecoder().decode([SystemFanControlState].self, from: encodedStates)) ?? []
    }

    public func setFanPercentage(fanIndex: Int, percentage: Double) -> Bool {
        guard let proxy = helperProxy() else { return false }
        let semaphore = DispatchSemaphore(value: 0)
        var result = false

        proxy.setFanPercentage(fanIndex: fanIndex, percentage: percentage) { success in
            result = success
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success else { return false }
        return result
    }

    public func setFanAutomatic(fanIndex: Int) -> Bool {
        guard let proxy = helperProxy() else { return false }
        let semaphore = DispatchSemaphore(value: 0)
        var result = false

        proxy.setFanAutomatic(fanIndex: fanIndex) { success in
            result = success
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success else { return false }
        return result
    }

    public func resetFanControl() -> Bool {
        guard let proxy = helperProxy() else { return false }
        let semaphore = DispatchSemaphore(value: 0)
        var result = false

        proxy.resetFanControl { success in
            result = success
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success else { return false }
        return result
    }

    private func helperProxy() -> SystemHardwareHelperProtocol? {
        connectionLock.lock()
        defer { connectionLock.unlock() }

        if connection == nil {
            let connection = NSXPCConnection(machServiceName: serviceName, options: .privileged)
            connection.remoteObjectInterface = NSXPCInterface(with: SystemHardwareHelperProtocol.self)
            connection.invalidationHandler = { [weak self] in
                self?.connectionLock.lock()
                self?.connection = nil
                self?.connectionLock.unlock()
            }
            connection.interruptionHandler = { [weak self] in
                self?.connectionLock.lock()
                self?.connection = nil
                self?.connectionLock.unlock()
            }
            connection.resume()
            self.connection = connection
        }

        guard let connection else { return nil }
        return connection.remoteObjectProxyWithErrorHandler { [weak self] _ in
            self?.connectionLock.lock()
            self?.connection = nil
            self?.connectionLock.unlock()
        } as? SystemHardwareHelperProtocol
    }

    private static func probe(serviceName: String, timeout: TimeInterval) -> Bool {
        let connection = NSXPCConnection(machServiceName: serviceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: SystemHardwareHelperProtocol.self)
        connection.resume()

        let semaphore = DispatchSemaphore(value: 0)
        var available = false

        let proxy = connection.remoteObjectProxyWithErrorHandler { _ in
            semaphore.signal()
        } as? SystemHardwareHelperProtocol

        proxy?.helperVersion { _ in
            available = true
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + timeout)
        connection.invalidate()
        return available
    }
}

