import Foundation
import OSLog

public enum AcMindLogCategory: String, Sendable, CaseIterable {
    case lifecycle = "Lifecycle"
    case storage = "Storage"
    case settings = "Settings"
    case permissions = "Permissions"
    case capture = "Capture"
    case clipboard = "Clipboard"
    case shortcuts = "Shortcuts"
    case systemStatus = "SystemStatus"
    case notifications = "Notifications"
    case ui = "UI"
    case input = "Input"
    case ai = "AI"
    case error = "Error"
}

public struct AcMindLogger: Sendable {
    private let logger: Logger

    public init(category: AcMindLogCategory, subsystem: String = Bundle.main.bundleIdentifier ?? "AcMind") {
        self.logger = Logger(subsystem: subsystem, category: category.rawValue)
    }

    public func debug(
        _ message: String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        logger.debug("\(Self.format(message, file: file, function: function, line: line), privacy: .public)")
    }

    public func info(
        _ message: String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        logger.info("\(Self.format(message, file: file, function: function, line: line), privacy: .public)")
    }

    public func notice(
        _ message: String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        logger.notice("\(Self.format(message, file: file, function: function, line: line), privacy: .public)")
    }

    public func warning(
        _ message: String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        logger.warning("\(Self.format(message, file: file, function: function, line: line), privacy: .public)")
    }

    public func error(
        _ message: String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        logger.error("\(Self.format(message, file: file, function: function, line: line), privacy: .public)")
    }

    public static func format(
        _ message: String,
        file: StaticString,
        function: StaticString,
        line: UInt
    ) -> String {
        "[\(file):\(line) \(function)] \(message)"
    }
}
