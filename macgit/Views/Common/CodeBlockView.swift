//
//  CodeBlockView.swift
//  macgit
//

//
//  macgit (Commit+) - a macOS Git client built with Swift and SwiftUI.
//  Copyright (C) 2026  Thanh Tran <trantienthanh2412@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Affero General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Affero General Public License for more details.
//
//  You should have received a copy of the GNU Affero General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
import SwiftUI

struct CodeBlockView: View {
    let text: String
    let fileExtension: String
    let fontSize: CGFloat

    init(text: String, fileExtension: String, fontSize: CGFloat = 12) {
        self.text = text
        self.fileExtension = fileExtension
        self.fontSize = fontSize
    }

    var body: some View {
        HStack(spacing: 0) {
            lineNumberGutter
            highlightedText
        }
    }

    private var lineNumberGutter: some View {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        return VStack(alignment: .trailing, spacing: 0) {
            ForEach(0..<lines.count, id: \.self) { index in
                Text("\(index + 1)")
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, 8)
                    .padding(.vertical, 1)
            }
        }
        .padding(.vertical, 8)
        .background(.secondary.opacity(0.05))
    }

    private var highlightedText: some View {
        let highlighter = SyntaxHighlighter(fileExtension: fileExtension)
        let attributed = highlighter.attributedString(for: text, fontSize: fontSize)
        return Text(attributed)
            .textSelection(.enabled)
            .lineSpacing(2)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
    }
}
