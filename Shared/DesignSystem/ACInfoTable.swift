import SwiftUI

struct ACInfoTableRow: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let valueColor: Color

    init(_ title: String, value: String, valueColor: Color = ACColors.primaryText) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
    }
}

struct ACInfoTable: View {
    let rows: [ACInfoTableRow]

    init(_ rows: [ACInfoTableRow]) {
        self.rows = rows
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack(alignment: .top, spacing: 16) {
                    Text(row.title)
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                        .frame(width: 108, alignment: .leading)

                    Text(row.value)
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(row.valueColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                .padding(.vertical, 10)

                if row.id != rows.last?.id {
                    Divider()
                        .overlay(ACColors.divider)
                }
            }
        }
    }
}
