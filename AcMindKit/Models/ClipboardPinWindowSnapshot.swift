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
}
