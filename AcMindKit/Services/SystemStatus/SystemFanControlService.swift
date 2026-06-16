import Foundation
import Combine

@MainActor
public final class SystemFanControlService: ObservableObject, SystemFanControlServiceProtocol {
    @Published public private(set) var fanControlStates: [SystemFanControlState] = []

    public var isAvailable: Bool {
        fanControlStates.contains(where: { $0.isAvailable })
    }

    private var transport: any SystemHardwareTransport

    public init(transport: (any SystemHardwareTransport)? = nil) {
        self.transport = transport ?? SystemHardwareAccess.shared.makeDefaultTransport()
        refreshTask()
    }

    public func refresh() async {
        refreshTask()
    }

    public func setFanPercentage(fanIndex: Int, percentage: Double) async -> Bool {
        guard transport.isAvailable else {
            return false
        }

        let success = transport.setFanPercentage(fanIndex: fanIndex, percentage: percentage)
        if success {
            refreshTask()
        }
        return success
    }

    public func setFanAutomatic(fanIndex: Int) async -> Bool {
        guard transport.isAvailable else {
            return false
        }

        let success = transport.setFanAutomatic(fanIndex: fanIndex)
        if success {
            refreshTask()
        }
        return success
    }

    public func resetFanControl() async -> Bool {
        guard transport.isAvailable else {
            return false
        }

        let success = transport.resetFanControl()
        if success {
            refreshTask()
        }
        return success
    }

    private func refreshTask() {
        transport = SystemHardwareAccess.shared.makeDefaultTransport()

        guard transport.isAvailable else {
            fanControlStates = []
            return
        }

        fanControlStates = transport.refreshFanControlStates()
    }
}
