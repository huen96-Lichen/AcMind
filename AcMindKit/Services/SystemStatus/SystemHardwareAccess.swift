import Foundation

public final class SystemHardwareAccess {
    public static let shared = SystemHardwareAccess()

    public static let defaultHelperMachServiceName = "com.acmind.systemstatus.helper"
    public static let defaultHelperInstallLabel = "com.acmind.systemstatus.helper"
    public static let defaultHelperBinaryName = "com.acmind.systemstatus.helper"

    public let helperMachServiceName = "com.acmind.systemstatus.helper"
    public let helperInstallLabel = "com.acmind.systemstatus.helper"
    public let helperBinaryName = "com.acmind.systemstatus.helper"

    public var embeddedHelperBinaryPath: String {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchServices")
            .appendingPathComponent(helperBinaryName)
            .path
    }

    private let helperProvider: () -> (any SystemHardwareTransport)?
    private let localProvider: () -> (any SystemHardwareTransport)?

    public init(
        helperProvider: @escaping () -> (any SystemHardwareTransport)? = { SystemHardwareXPCTransport(serviceName: SystemHardwareAccess.defaultHelperMachServiceName) },
        localProvider: @escaping () -> (any SystemHardwareTransport)? = { SystemSMCBridge() }
    ) {
        self.helperProvider = helperProvider
        self.localProvider = localProvider
    }

    public func makeDefaultTransport() -> any SystemHardwareTransport {
        if let helper = helperProvider(), helper.isAvailable {
            if helper.refreshFanControlStates().isEmpty == false {
                return helper
            }
        }

        if let local = localProvider(), local.isAvailable {
            return local
        }

        if let helper = helperProvider(), helper.isAvailable {
            return helper
        }

        return SystemUnavailableHardwareTransport()
    }
}

private final class SystemUnavailableHardwareTransport: SystemHardwareTransport {
    let isAvailable = false

    func refreshFanControlStates() -> [SystemFanControlState] {
        []
    }

    func setFanPercentage(fanIndex: Int, percentage: Double) -> Bool {
        false
    }

    func setFanAutomatic(fanIndex: Int) -> Bool {
        false
    }

    func resetFanControl() -> Bool {
        false
    }
}
