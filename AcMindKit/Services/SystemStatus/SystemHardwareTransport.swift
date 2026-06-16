import Foundation

public protocol SystemHardwareTransport: AnyObject {
    var isAvailable: Bool { get }

    func refreshFanControlStates() -> [SystemFanControlState]
    func setFanPercentage(fanIndex: Int, percentage: Double) -> Bool
    func setFanAutomatic(fanIndex: Int) -> Bool
    func resetFanControl() -> Bool
}

