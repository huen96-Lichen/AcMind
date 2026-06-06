import CoreGraphics

public struct ClipboardPinWindowSnapshot: Equatable, Sendable {
    public let itemId: String
    public let isVisible: Bool
    public let isAlwaysOnTop: Bool
    public let levelRawValue: Int
    public let expectedAlwaysOnTopLevelRawValue: Int
    public let frame: CGRect
    public let screenFrame: CGRect?
    public let displayFrame: CGRect

    public init(
        itemId: String,
        isVisible: Bool,
        isAlwaysOnTop: Bool,
        levelRawValue: Int,
        expectedAlwaysOnTopLevelRawValue: Int,
        frame: CGRect,
        screenFrame: CGRect?,
        displayFrame: CGRect
    ) {
        self.itemId = itemId
        self.isVisible = isVisible
        self.isAlwaysOnTop = isAlwaysOnTop
        self.levelRawValue = levelRawValue
        self.expectedAlwaysOnTopLevelRawValue = expectedAlwaysOnTopLevelRawValue
        self.frame = frame
        self.screenFrame = screenFrame
        self.displayFrame = displayFrame
    }

    public var isAtExpectedAlwaysOnTopLevel: Bool {
        isAlwaysOnTop && levelRawValue == expectedAlwaysOnTopLevelRawValue
    }

    public var diagnosticReason: String {
        if isVisible == false {
            return "hidden"
        }
        if isAlwaysOnTop == false {
            return "not always-on-top"
        }
        if isAtExpectedAlwaysOnTopLevel == false {
            return "level mismatch"
        }
        if screenFrame == nil {
            return "missing screen frame"
        }
        return "ok"
    }

    public var diagnosticPriority: Int {
        switch diagnosticReason {
        case "ok":
            return 0
        case "missing screen frame":
            return 1
        case "level mismatch":
            return 2
        case "not always-on-top":
            return 3
        case "hidden":
            return 4
        default:
            return 5
        }
    }
}
