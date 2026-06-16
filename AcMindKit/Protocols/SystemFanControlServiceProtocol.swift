import Foundation

@MainActor
public protocol SystemFanControlServiceProtocol: AnyObject {
    var fanControlStates: [SystemFanControlState] { get }
    var isAvailable: Bool { get }

    func refresh() async
    func setFanPercentage(fanIndex: Int, percentage: Double) async -> Bool
    func setFanAutomatic(fanIndex: Int) async -> Bool
    func resetFanControl() async -> Bool
}
