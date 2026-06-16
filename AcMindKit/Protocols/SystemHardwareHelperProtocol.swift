import Foundation

@objc public protocol SystemHardwareHelperProtocol {
    func helperVersion(completion: @escaping (String) -> Void)
    func refreshFanControlStates(completion: @escaping (Data?) -> Void)
    func setFanPercentage(fanIndex: Int, percentage: Double, completion: @escaping (Bool) -> Void)
    func setFanAutomatic(fanIndex: Int, completion: @escaping (Bool) -> Void)
    func resetFanControl(completion: @escaping (Bool) -> Void)
}

