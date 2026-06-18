//
//  ConflictCodeView.swift
//  macgit
//

import SwiftUI

/// A read-only code view that shows line numbers and can highlight specific lines.
struct ConflictCodeView: View {
    let text: String
    let fileExtension: String
    let highlightedLines: Set<Int>
    let highlightColor: Color
    let fontSize: CGFloat = 12

    private var lines: [String] {
        var components = text.components(separatedBy: "\n")
        // Remove trailing empty component caused by trailing newline
        if components.last == "" {
            components.removeLast()
        }
        return components
    }

    var body: some View {
        HStack(spacing: 0) {
            lineNumbers
            codeContent
        }
    }

    // MARK: - Line Numbers

    private var lineNumbers: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(0..<lines.count, id: \.self) { index in
                let lineNum = index + 1
                Text("\(lineNum)")
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, 8)
                    .padding(.vertical, 1)
                    .background(backgroundColor(for: lineNum))
            }
        }
        .padding(.vertical, 8)
        .background(.secondary.opacity(0.05))
    }

    // MARK: - Code Content

    private var codeContent: some View {
        let highlighter = SyntaxHighlighter(fileExtension: fileExtension)

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<lines.count, id: \.self) { index in
                let lineNum = index + 1
                let attributed = highlighter.attributedString(for: lines[index], fontSize: fontSize)

                Text(attributed)
                    .font(.system(size: fontSize, design: .monospaced))
                    .lineSpacing(2)
                    .padding(.vertical, 1)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(backgroundColor(for: lineNum))
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func backgroundColor(for lineNum: Int) -> Color {
        highlightedLines.contains(lineNum) ? highlightColor.opacity(0.2) : Color.clear
    }
}
