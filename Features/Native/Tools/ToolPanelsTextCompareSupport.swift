import AppKit
import SwiftUI

struct DiffLine: Identifiable {
    enum Kind {
        case same
        case insert
        case delete
    }

    let id = UUID()
    let kind: Kind
    let text: String
    let leftLineNumber: Int?
    let rightLineNumber: Int?
}

struct TextComparisonResult {
    let lines: [DiffLine]
    let summary: String
}

enum TextComparisonSupport {
    static func compare(leftLines: [String], rightLines: [String]) -> TextComparisonResult {
        let n = leftLines.count
        let m = rightLines.count

        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)

        if n > 0 && m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    if leftLines[i] == rightLines[j] {
                        dp[i][j] = dp[i + 1][j + 1] + 1
                    } else {
                        dp[i][j] = max(dp[i + 1][j], dp[i][j + 1])
                    }
                }
            }
        }

        var lines: [DiffLine] = []
        var i = 0
        var j = 0
        var leftLineNumber = 1
        var rightLineNumber = 1
        var sameCount = 0
        var insertCount = 0
        var deleteCount = 0

        while i < n && j < m {
            if leftLines[i] == rightLines[j] {
                lines.append(
                    DiffLine(
                        kind: .same,
                        text: leftLines[i],
                        leftLineNumber: leftLineNumber,
                        rightLineNumber: rightLineNumber
                    )
                )
                sameCount += 1
                i += 1
                j += 1
                leftLineNumber += 1
                rightLineNumber += 1
            } else if dp[i + 1][j] >= dp[i][j + 1] {
                lines.append(
                    DiffLine(
                        kind: .delete,
                        text: leftLines[i],
                        leftLineNumber: leftLineNumber,
                        rightLineNumber: nil
                    )
                )
                deleteCount += 1
                i += 1
                leftLineNumber += 1
            } else {
                lines.append(
                    DiffLine(
                        kind: .insert,
                        text: rightLines[j],
                        leftLineNumber: nil,
                        rightLineNumber: rightLineNumber
                    )
                )
                insertCount += 1
                j += 1
                rightLineNumber += 1
            }
        }

        while i < n {
            lines.append(
                DiffLine(
                    kind: .delete,
                    text: leftLines[i],
                    leftLineNumber: leftLineNumber,
                    rightLineNumber: nil
                )
            )
            deleteCount += 1
            i += 1
            leftLineNumber += 1
        }

        while j < m {
            lines.append(
                DiffLine(
                    kind: .insert,
                    text: rightLines[j],
                    leftLineNumber: nil,
                    rightLineNumber: rightLineNumber
                )
            )
            insertCount += 1
            j += 1
            rightLineNumber += 1
        }

        let summary = "左侧 \(n) 行，右侧 \(m) 行，相同 \(sameCount) 行，新增 \(insertCount) 行，删除 \(deleteCount) 行"
        return TextComparisonResult(lines: lines, summary: summary)
    }
}

struct DiffLineRow: View {
    let line: DiffLine

    private var tint: Color {
        switch line.kind {
        case .same:
            return .secondary
        case .insert:
            return .green
        case .delete:
            return .red
        }
    }

    private var background: Color {
        switch line.kind {
        case .same:
            return Color.clear
        case .insert:
            return Color.green.opacity(0.08)
        case .delete:
            return Color.red.opacity(0.08)
        }
    }

    private var marker: String {
        switch line.kind {
        case .same:
            return " "
        case .insert:
            return "+"
        case .delete:
            return "−"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(line.leftLineNumber.map(String.init) ?? " ")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Color.secondary)
                .frame(width: 36, alignment: .trailing)

            Text(line.rightLineNumber.map(String.init) ?? " ")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Color.secondary)
                .frame(width: 36, alignment: .trailing)

            Text(marker)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
                .frame(width: 18)

            Text(line.text.isEmpty ? " " : line.text)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color.primary)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 8)
    }
}
