import Foundation

public actor PluginSandbox {
    private let allowedPaths: [URL]
    
    public init(pluginId: String) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AcMind/Plugins/\(pluginId)")
        allowedPaths = [base]
    }
    
    public func validateAccess(path: URL) -> Bool {
        return allowedPaths.contains { path.path.hasPrefix($0.path) }
    }
}
