import Foundation
import SwiftUI

public struct ClipboardTag: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public var name: String
    public var color: String

    public init(
        id: String = UUID().uuidString,
        name: String,
        color: String = "#3B82F6"
    ) {
        self.id = id
        self.name = name
        self.color = color
    }

    public var swiftColor: Color {
        Color(hex: color) ?? .blue
    }
}

private extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
