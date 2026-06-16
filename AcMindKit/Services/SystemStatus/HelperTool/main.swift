import Foundation
import AcMindKit

private final class SystemStatusHelperServer: NSObject, NSXPCListenerDelegate, SystemHardwareHelperProtocol {
    private let listener: NSXPCListener
    private let transport: SystemSMCBridge?

    override init() {
        self.listener = NSXPCListener(machServiceName: SystemHardwareAccess.defaultHelperMachServiceName)
        self.transport = SystemSMCBridge()
        super.init()
        self.listener.delegate = self
    }

    func run() {
        listener.resume()
        RunLoop.current.run()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: SystemHardwareHelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    func helperVersion(completion: @escaping (String) -> Void) {
        completion(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0")
    }

    func refreshFanControlStates(completion: @escaping (Data?) -> Void) {
        completion(encodeFanStates())
    }

    func setFanPercentage(fanIndex: Int, percentage: Double, completion: @escaping (Bool) -> Void) {
        completion(transport?.setFanPercentage(fanIndex: fanIndex, percentage: percentage) ?? false)
    }

    func setFanAutomatic(fanIndex: Int, completion: @escaping (Bool) -> Void) {
        completion(transport?.setFanAutomatic(fanIndex: fanIndex) ?? false)
    }

    func resetFanControl(completion: @escaping (Bool) -> Void) {
        completion(transport?.resetFanControl() ?? false)
    }

    private func encodeFanStates() -> Data? {
        let states = transport?.refreshFanControlStates() ?? []
        return try? JSONEncoder().encode(states)
    }
}

SystemStatusHelperServer().run()

