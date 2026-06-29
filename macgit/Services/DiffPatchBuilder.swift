//
//  DiffPatchBuilder.swift
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
import Foundation

enum DiffPatchBuilder {
    nonisolated static func patchString(for hunk: DiffHunk, filePath: String) -> String {
        let linesString = hunk.lines.map { line in
            switch line.type {
            case .added:
                return "+\(line.text)"
            case .removed:
                return "-\(line.text)"
            case .context:
                return " \(line.text)"
            case .header:
                return line.text
            case .conflictMarker:
                return " \(line.text)"
            }
        }.joined(separator: "\n")

        return "--- a/\(filePath)\n+++ b/\(filePath)\n\(hunk.header)\n\(linesString)\n"
    }

    nonisolated static func patchString(for hunk: DiffHunk, selectedLines: [DiffLine], filePath: String) -> String {
        let selectedIDs = Set(selectedLines.map(\.id))
        var oldCount = 0
        var newCount = 0
        var filteredLines: [String] = []

        for line in hunk.lines {
            switch line.type {
            case .context:
                filteredLines.append(" \(line.text)")
                oldCount += 1
                newCount += 1
            case .added:
                if selectedIDs.contains(line.id) {
                    filteredLines.append("+\(line.text)")
                    newCount += 1
                }
            case .removed:
                if selectedIDs.contains(line.id) {
                    filteredLines.append("-\(line.text)")
                    oldCount += 1
                }
            case .header:
                filteredLines.append(line.text)
            case .conflictMarker:
                filteredLines.append(" \(line.text)")
                oldCount += 1
                newCount += 1
            }
        }

        let pattern = #"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: hunk.header, range: NSRange(hunk.header.startIndex..., in: hunk.header)),
              let oldStartRange = Range(match.range(at: 1), in: hunk.header),
              let newStartRange = Range(match.range(at: 2), in: hunk.header),
              let oldStart = Int(hunk.header[oldStartRange]),
              let newStart = Int(hunk.header[newStartRange]) else {
            return patchString(for: hunk, filePath: filePath)
        }

        let newHeader = "@@ -\(oldStart),\(oldCount) +\(newStart),\(newCount) @@"
        return "--- a/\(filePath)\n+++ b/\(filePath)\n\(newHeader)\n\(filteredLines.joined(separator: "\n"))\n"
    }
}
