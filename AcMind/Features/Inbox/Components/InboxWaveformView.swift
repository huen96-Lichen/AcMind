import SwiftUI

struct InboxWaveformView: View {
    let data: [CGFloat]
    let width: CGFloat
    let height: CGFloat
    let color: Color
    
    init(data: [CGFloat], width: CGFloat = 220, height: CGFloat = 18, color: Color = InboxColors.accentOrange.opacity(0.65)) {
        self.data = data
        self.width = width
        self.height = height
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(data.indices, id: \.self) { index in
                Rectangle()
                    .fill(color)
                    .frame(width: 2, height: height * (data[index] / 20))
                    .cornerRadius(1)
            }
        }
        .frame(width: width, height: height, alignment: .leading)
        .clipped()
    }
}