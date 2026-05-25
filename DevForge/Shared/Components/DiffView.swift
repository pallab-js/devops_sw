import SwiftUI

struct DiffView: View {
    let diffText: String

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(parsedLines.enumerated()), id: \.offset) { _, line in
                    diffLineView(line)
                }
            }
            .font(.appMonospaceSmall)
            .padding(Spacing.xs)
        }
        .background(Color(.textBackgroundColor), in: Rectangle())
    }

    private var parsedLines: [DiffLine] {
        diffText.components(separatedBy: "\n").map { line in
            if line.hasPrefix("+++") || line.hasPrefix("---") {
                return DiffLine(content: line, type: .header)
            } else if line.hasPrefix("@@") {
                return DiffLine(content: line, type: .position)
            } else if line.hasPrefix("+") {
                return DiffLine(content: line, type: .addition)
            } else if line.hasPrefix("-") {
                return DiffLine(content: line, type: .deletion)
            } else {
                return DiffLine(content: line, type: .context)
            }
        }
    }

    private func diffLineView(_ line: DiffLine) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(linePrefix(line.type))
                .foregroundStyle(lineColor(line.type))
                .frame(width: 20, alignment: .trailing)
            Text(line.content)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, Spacing.xxs)
        .background(lineBackground(line.type))
    }

    private func linePrefix(_ type: DiffLineType) -> String {
        switch type {
        case .addition: "+"
        case .deletion: "-"
        default: " "
        }
    }

    private func lineColor(_ type: DiffLineType) -> Color {
        switch type {
        case .addition: .green
        case .deletion: .red
        case .position: .cyan
        case .header: .secondary
        case .context: .primary
        }
    }

    private func lineBackground(_ type: DiffLineType) -> Color {
        switch type {
        case .addition: Color.green.opacity(0.1)
        case .deletion: Color.red.opacity(0.1)
        default: .clear
        }
    }
}

struct DiffLine {
    let content: String
    let type: DiffLineType
}

enum DiffLineType {
    case addition, deletion, context, header, position
}
