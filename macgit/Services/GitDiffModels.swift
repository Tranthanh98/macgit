//
//  GitDiffModels.swift
//  macgit
//

import Foundation

enum DiffLineType {
    case context
    case added
    case removed
    case header
    case conflictMarker
}

struct DiffLine: Identifiable {
    let id = UUID()
    let oldLineNumber: Int?
    let newLineNumber: Int?
    let text: String
    let type: DiffLineType
}

struct DiffHunk: Identifiable {
    let id = UUID()
    let header: String
    let lines: [DiffLine]
}

enum DiffParser {
    static func parse(_ raw: String) -> [DiffHunk] {
        var hunks: [DiffHunk] = []
        var currentLines: [DiffLine] = []
        var currentHeader = ""
        var oldLine = 0
        var newLine = 0

        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false)
        var inHunk = false

        for line in lines {
            let text = String(line)

            if text.hasPrefix("@@") {
                // Start of hunk
                if inHunk {
                    hunks.append(DiffHunk(header: currentHeader, lines: currentLines))
                }
                inHunk = true
                currentHeader = text
                currentLines = []

                // Parse line numbers: @@ -start,count +start,count @@
                if let range = text.range(of: "@@ -"),
                   let atRange = text[range.upperBound...].range(of: " @@") {
                    let numbersPart = String(text[range.upperBound..<atRange.lowerBound])
                    let parts = numbersPart.split(separator: " ")
                    if parts.count == 2 {
                        let oldPart = parts[0].split(separator: ",")
                        let newPart = parts[1].split(separator: ",")
                        oldLine = Int(oldPart[0]) ?? 0
                        if oldPart.count > 1, let count = Int(oldPart[1]), count == 0 {
                            // Deleted file or new file
                        }
                        newLine = Int(String(newPart[0]).dropFirst()) ?? 0
                    }
                }
                continue
            }

            if !inHunk {
                continue
            }

            guard !text.isEmpty else {
                currentLines.append(DiffLine(oldLineNumber: nil, newLineNumber: nil, text: "", type: .context))
                continue
            }

            let prefix = text.prefix(1)
            let content = String(text.dropFirst())
            let isConflictMarker = content.hasPrefix("<<<<<<<") || content.hasPrefix("=======") || content.hasPrefix(">>>>>>>")

            switch prefix {
            case "+":
                if isConflictMarker {
                    currentLines.append(DiffLine(oldLineNumber: nil, newLineNumber: newLine, text: content, type: .conflictMarker))
                } else {
                    currentLines.append(DiffLine(oldLineNumber: nil, newLineNumber: newLine, text: content, type: .added))
                }
                newLine += 1
            case "-":
                if isConflictMarker {
                    currentLines.append(DiffLine(oldLineNumber: oldLine, newLineNumber: nil, text: content, type: .conflictMarker))
                } else {
                    currentLines.append(DiffLine(oldLineNumber: oldLine, newLineNumber: nil, text: content, type: .removed))
                }
                oldLine += 1
            case " ":
                if isConflictMarker {
                    currentLines.append(DiffLine(oldLineNumber: oldLine, newLineNumber: newLine, text: content, type: .conflictMarker))
                } else {
                    currentLines.append(DiffLine(oldLineNumber: oldLine, newLineNumber: newLine, text: content, type: .context))
                }
                oldLine += 1
                newLine += 1
            case "\\":
                // "\ No newline at end of file"
                currentLines.append(DiffLine(oldLineNumber: nil, newLineNumber: nil, text: text, type: .header))
            default:
                break
            }
        }

        if inHunk && !currentLines.isEmpty {
            hunks.append(DiffHunk(header: currentHeader, lines: currentLines))
        }

        return hunks
    }
}
