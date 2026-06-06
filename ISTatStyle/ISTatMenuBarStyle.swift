import SwiftUI

// MARK: - Theme & Color System

struct ISTheme {
    let background: Color
    let surface: Color
    let surfaceElevated: Color
    let surfacePressed: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textDisabled: Color
    let divider: Color
    let dividerSubtle: Color
    let accent: Color
    let accentHover: Color
    let accentPressed: Color
    let graphPrimary: Color
    let graphSecondary: Color
    let graphTertiary: Color
    let graphBackground: Color
    let graphBorder: Color
    let statusGreen: Color
    let statusYellow: Color
    let statusRed: Color
    let statusBlue: Color
    let statusGreenBg: Color
    let statusYellowBg: Color
    let statusRedBg: Color

    static let dark = ISTheme(
        background: Color(white: 0.11),
        surface: Color(white: 0.15),
        surfaceElevated: Color(white: 0.19),
        surfacePressed: Color(white: 0.12),
        textPrimary: Color(white: 0.95),
        textSecondary: Color(white: 0.65),
        textTertiary: Color(white: 0.45),
        textDisabled: Color(white: 0.30),
        divider: Color(white: 0.22),
        dividerSubtle: Color(white: 0.18),
        accent: Color(hue: 0.60, saturation: 0.85, brightness: 1.0),
        accentHover: Color(hue: 0.60, saturation: 0.75, brightness: 1.0),
        accentPressed: Color(hue: 0.60, saturation: 0.90, brightness: 0.9),
        graphPrimary: Color(hue: 0.60, saturation: 0.85, brightness: 1.0),
        graphSecondary: Color(hue: 0.50, saturation: 0.70, brightness: 0.95),
        graphTertiary: Color(hue: 0.0, saturation: 0.65, brightness: 0.95),
        graphBackground: Color(white: 0.13),
        graphBorder: Color(white: 0.20),
        statusGreen: Color(hue: 0.38, saturation: 0.75, brightness: 0.70),
        statusYellow: Color(hue: 0.12, saturation: 0.85, brightness: 0.95),
        statusRed: Color(hue: 0.0, saturation: 0.70, brightness: 0.90),
        statusBlue: Color(hue: 0.60, saturation: 0.85, brightness: 1.0),
        statusGreenBg: Color(hue: 0.38, saturation: 0.75, brightness: 0.70).opacity(0.15),
        statusYellowBg: Color(hue: 0.12, saturation: 0.85, brightness: 0.95).opacity(0.12),
        statusRedBg: Color(hue: 0.0, saturation: 0.70, brightness: 0.90).opacity(0.12)
    )

    static let light = ISTheme(
        background: Color(white: 0.96),
        surface: .white,
        surfaceElevated: .white,
        surfacePressed: Color(white: 0.94),
        textPrimary: Color(white: 0.10),
        textSecondary: Color(white: 0.40),
        textTertiary: Color(white: 0.55),
        textDisabled: Color(white: 0.72),
        divider: Color(white: 0.85),
        dividerSubtle: Color(white: 0.90),
        accent: Color(hue: 0.60, saturation: 0.80, brightness: 0.85),
        accentHover: Color(hue: 0.60, saturation: 0.75, brightness: 0.75),
        accentPressed: Color(hue: 0.60, saturation: 0.85, brightness: 0.70),
        graphPrimary: Color(hue: 0.60, saturation: 0.80, brightness: 0.85),
        graphSecondary: Color(hue: 0.50, saturation: 0.60, brightness: 0.75),
        graphTertiary: Color(hue: 0.0, saturation: 0.60, brightness: 0.80),
        graphBackground: Color(white: 0.92),
        graphBorder: Color(white: 0.82),
        statusGreen: Color(hue: 0.38, saturation: 0.65, brightness: 0.55),
        statusYellow: Color(hue: 0.12, saturation: 0.80, brightness: 0.80),
        statusRed: Color(hue: 0.0, saturation: 0.65, brightness: 0.75),
        statusBlue: Color(hue: 0.60, saturation: 0.80, brightness: 0.85),
        statusGreenBg: Color(hue: 0.38, saturation: 0.65, brightness: 0.55).opacity(0.10),
        statusYellowBg: Color(hue: 0.12, saturation: 0.80, brightness: 0.80).opacity(0.10),
        statusRedBg: Color(hue: 0.0, saturation: 0.65, brightness: 0.75).opacity(0.10)
    )
}

// MARK: - Color Key System

enum ISColorKey {
    case cpuUser, cpuSystem, cpuAll, cpuEfficiency, cpuPerformance
    case memoryApp, memoryWired, memoryCompressed, memoryPressure, memorySwap
    case diskSpace, diskRead, diskWrite
    case networkDownload, networkUpload
    case batteryCharging, batteryDraining, batteryHealth
    case gpuProcessor, gpuMemory
    case sensor

    func resolved(in theme: ISTheme) -> Color {
        switch self {
        case .cpuUser, .cpuAll:          return theme.graphPrimary
        case .cpuSystem:                  return theme.graphTertiary
        case .cpuEfficiency:              return theme.statusGreen
        case .cpuPerformance:             return theme.accent
        case .memoryApp:                  return theme.graphPrimary
        case .memoryWired:                return theme.graphSecondary
        case .memoryCompressed:           return theme.graphTertiary
        case .memoryPressure:             return theme.statusYellow
        case .memorySwap:                 return theme.textTertiary
        case .diskSpace:                  return theme.graphPrimary
        case .diskRead:                   return theme.graphPrimary
        case .diskWrite:                  return theme.graphTertiary
        case .networkDownload:            return theme.graphPrimary
        case .networkUpload:              return theme.graphTertiary
        case .batteryCharging:            return theme.statusGreen
        case .batteryDraining:            return theme.statusYellow
        case .batteryHealth:              return theme.graphPrimary
        case .gpuProcessor:               return theme.graphPrimary
        case .gpuMemory:                  return theme.graphSecondary
        case .sensor:                     return theme.graphPrimary
        }
    }
}

// MARK: - Typography (SF Pro, tight scale 1.15 ratio)

struct ISTypography {
    // Menubar: compact, high density
    static let menubarLabel = Font.system(size: 10, weight: .medium, design: .default)
    static let menubarValue = Font.system(size: 10, weight: .semibold, design: .default)

    // Section: clear hierarchy
    static let sectionHeader = Font.system(size: 11, weight: .semibold, design: .default)
    static let sectionBody = Font.system(size: 11, weight: .regular, design: .default)
    static let sectionCaption = Font.system(size: 10, weight: .regular, design: .default)

    // Data: monospaced for alignment
    static let dataLabel = Font.system(size: 10, weight: .regular, design: .monospaced)
    static let dataValue = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let dataLarge = Font.system(size: 13, weight: .semibold, design: .monospaced)

    // Graph: minimal
    static let graphLabel = Font.system(size: 9, weight: .medium, design: .default)
    static let graphValue = Font.system(size: 10, weight: .semibold, design: .monospaced)

    // Status
    static let statusBadge = Font.system(size: 9, weight: .semibold, design: .default)
}

// MARK: - Spacing & Layout Constants

struct ISLayout {
    // Menu dimensions
    static let menuWidth: CGFloat = 300
    static let menuPaddingH: CGFloat = 12
    static let menuPaddingV: CGFloat = 10

    // Section rhythm
    static let sectionGap: CGFloat = 10
    static let sectionInternalGap: CGFloat = 6
    static let itemGap: CGFloat = 3
    static let dividerPadding: CGFloat = 6

    // Graph dimensions
    static let cornerRadius: CGFloat = 5
    static let cornerRadiusSmall: CGFloat = 3
    static let graphHeight: CGFloat = 40
    static let historyGraphHeight: CGFloat = 56
    static let circularGraphSize: CGFloat = 48
    static let barHeight: CGFloat = 4
    static let barHeightThin: CGFloat = 3

    // Menubar
    static let menubarItemSpacing: CGFloat = 4
    static let menubarIconSize: CGFloat = 11
    static let menubarHeight: CGFloat = 16

    // Touch targets
    static let minTouchTarget: CGFloat = 28
}
