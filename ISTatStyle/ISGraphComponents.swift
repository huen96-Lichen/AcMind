import SwiftUI

// MARK: - Vertical Bar Graph (Menubar)

struct ISVerticalBarGraph: View {
    let values: [CGFloat]
    let colors: [Color]
    var width: CGFloat = 12
    var height: CGFloat = ISLayout.menubarHeight
    var spacing: CGFloat = 1
    var cornerRadius: CGFloat = ISLayout.cornerRadiusSmall

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<values.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(colors[i % colors.count])
                    .frame(width: width / CGFloat(values.count) - spacing,
                           height: height * min(max(values[i], 0), 1))
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - History Graph (Sparkline)

struct ISHistoryGraph: View {
    let dataPoints: [CGFloat]
    let color: Color
    var secondaryColor: Color?
    var secondaryData: [CGFloat]?
    var showBorder: Bool = true
    var showBackground: Bool = true
    var height: CGFloat = ISLayout.historyGraphHeight

    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                if showBackground {
                    RoundedRectangle(cornerRadius: ISLayout.cornerRadius)
                        .fill(theme.graphBackground)
                }

                if showBorder {
                    RoundedRectangle(cornerRadius: ISLayout.cornerRadius)
                        .strokeBorder(theme.graphBorder, lineWidth: 0.5)
                }

                if let sec = secondaryData, let secColor = secondaryColor {
                    graphPath(data: sec, in: CGSize(width: w, height: h))
                        .fill(secColor.opacity(0.2))
                    graphPath(data: sec, in: CGSize(width: w, height: h))
                        .stroke(secColor, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                }

                graphPath(data: dataPoints, in: CGSize(width: w, height: h))
                    .fill(color.opacity(0.2))
                graphPath(data: dataPoints, in: CGSize(width: w, height: h))
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: height)
    }

    private func graphPath(data: [CGFloat], in size: CGSize) -> Path {
        Path { path in
            guard data.count > 1 else { return }
            let step = size.width / CGFloat(data.count - 1)
            let padding: CGFloat = 2
            let availableHeight = size.height - padding * 2

            path.move(to: CGPoint(x: 0, y: size.height - padding - data[0] * availableHeight))
            for i in 1..<data.count {
                let x = CGFloat(i) * step
                let y = size.height - padding - data[i] * availableHeight
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
    }
}

// MARK: - Circular Graph (Ring)

struct ISCircularGraph: View {
    let value: CGFloat
    let color: Color
    var trackColor: Color?
    var lineWidth: CGFloat = 4
    var size: CGFloat = ISLayout.circularGraphSize

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor ?? theme.graphBackground, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(max(value, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(value * 100))%")
                .font(ISTypography.graphLabel)
                .foregroundStyle(theme.textPrimary)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Multi-Ring Circular Graph

struct ISMultiRingGraph: View {
    struct RingData {
        let value: CGFloat
        let color: Color
    }

    let rings: [RingData]
    var lineWidth: CGFloat = 3
    var spacing: CGFloat = 3
    var size: CGFloat = 56

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            ForEach(0..<rings.count, id: \.self) { i in
                let ringSize = size - CGFloat(i) * (lineWidth + spacing)

                Circle()
                    .stroke(theme.graphBackground, lineWidth: lineWidth)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .trim(from: 0, to: min(max(rings[i].value, 0), 1))
                    .stroke(rings[i].color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: ringSize, height: ringSize)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Pie Graph

struct ISPieGraph: View {
    let slices: [(CGFloat, Color)]
    var size: CGFloat = 40
    var innerRadius: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<slices.count, id: \.self) { i in
                let startAngle = slices[..<i].reduce(0) { $0 + $1.0 }
                let endAngle = startAngle + slices[i].0

                PieSlice(startAngle: .degrees(startAngle * 360 - 90),
                         endAngle: .degrees(endAngle * 360 - 90))
                    .fill(slices[i].1)
            }

            if innerRadius > 0 {
                Circle()
                    .fill(Color.clear)
                    .frame(width: innerRadius * 2, height: innerRadius * 2)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius,
                    startAngle: startAngle, endAngle: endAngle,
                    clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Space Bar (Disk Usage)

struct ISSpaceBar: View {
    let used: CGFloat
    let color: Color
    var height: CGFloat = ISLayout.barHeight

    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(theme.graphBackground)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geo.size.width * min(max(used, 0), 1))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Activity Dots

struct ISActivityDots: View {
    let readActive: Bool
    let writeActive: Bool
    let readColor: Color
    let writeColor: Color

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(readActive ? readColor : theme.graphBackground)
                .frame(width: 5, height: 5)
            Circle()
                .fill(writeActive ? writeColor : theme.graphBackground)
                .frame(width: 5, height: 5)
        }
    }
}
