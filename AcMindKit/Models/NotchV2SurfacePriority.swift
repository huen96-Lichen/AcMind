import Foundation

public enum NotchV2SurfacePriority: Int, CaseIterable, Sendable {
    case voiceRecording = 0
    case voiceProcessing = 1
    case screenshot = 2
    case systemEventHUD = 3
    case music = 4
    case defaultState = 5
}
