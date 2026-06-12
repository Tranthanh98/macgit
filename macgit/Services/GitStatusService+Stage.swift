//
//  GitStatusService+Stage.swift
//  macgit
//

import Foundation

extension GitStatusService {
    func stage(file: StatusFile, in repositoryURL: URL) async throws {
        _ = try await runGit(arguments: ["add", file.path], in: repositoryURL)
    }

    func unstage(file: StatusFile, in repositoryURL: URL) async throws {
        _ = try await runGit(arguments: ["reset", "HEAD", "--", file.path], in: repositoryURL)
    }

    func stageAll(files: [StatusFile], in repositoryURL: URL) async throws {
        guard !files.isEmpty else { return }
        var arguments = ["add", "--"]
        arguments.append(contentsOf: files.map(\.path))
        _ = try await runGit(arguments: arguments, in: repositoryURL)
    }

    func unstageAll(files: [StatusFile], in repositoryURL: URL) async throws {
        guard !files.isEmpty else { return }
        var arguments = ["reset", "HEAD", "--"]
        arguments.append(contentsOf: files.map(\.path))
        _ = try await runGit(arguments: arguments, in: repositoryURL)
    }

    // MARK: - Hunk / Line Operations

    func stage(hunk: DiffHunk, file: StatusFile, in repositoryURL: URL) async throws {
        guard file.status != .untracked else {
            throw GitError.commandFailed("Cannot stage hunk for untracked file")
        }
        let patch = patchString(for: hunk, filePath: file.path)
        try await applyPatch(patch, in: repositoryURL, cached: true)
    }

    func discard(hunk: DiffHunk, file: StatusFile, in repositoryURL: URL) async throws {
        guard file.status != .untracked else {
            throw GitError.commandFailed("Cannot discard hunk for untracked file")
        }
        let patch = patchString(for: hunk, filePath: file.path)
        try await applyPatch(patch, in: repositoryURL, reverse: true)
    }

    func stage(lines: [DiffLine], hunk: DiffHunk, file: StatusFile, in repositoryURL: URL) async throws {
        guard file.status != .untracked else {
            throw GitError.commandFailed("Cannot stage lines for untracked file")
        }
        let patch = patchString(for: hunk, selectedLines: lines, filePath: file.path)
        try await applyPatch(patch, in: repositoryURL, cached: true)
    }

    func discard(lines: [DiffLine], hunk: DiffHunk, file: StatusFile, in repositoryURL: URL) async throws {
        guard file.status != .untracked else {
            throw GitError.commandFailed("Cannot discard lines for untracked file")
        }
        let patch = patchString(for: hunk, selectedLines: lines, filePath: file.path)
        try await applyPatch(patch, in: repositoryURL, reverse: true)
    }

    func unstage(hunk: DiffHunk, file: StatusFile, in repositoryURL: URL) async throws {
        let patch = patchString(for: hunk, filePath: file.path)
        try await applyPatch(patch, in: repositoryURL, cached: true, reverse: true)
    }

    func unstage(lines: [DiffLine], hunk: DiffHunk, file: StatusFile, in repositoryURL: URL) async throws {
        let patch = patchString(for: hunk, selectedLines: lines, filePath: file.path)
        try await applyPatch(patch, in: repositoryURL, cached: true, reverse: true)
    }

    // MARK: - Patch Helpers

    private func applyPatch(_ patch: String, in repositoryURL: URL, cached: Bool = false, reverse: Bool = false) async throws {
        var arguments = ["apply"]
        if cached { arguments.append("--cached") }
        if reverse { arguments.append("--reverse") }
        arguments.append("-")

        let executable = gitExecutable()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        task.currentDirectoryURL = repositoryURL
        task.environment = ProcessInfo.processInfo.environment

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        task.standardInput = stdin
        task.standardOutput = stdout
        task.standardError = stderr

        return try await withCheckedThrowingContinuation { continuation in
            task.terminationHandler = { process in
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errData, encoding: .utf8) ?? ""
                if process.terminationStatus != 0 {
                    continuation.resume(throwing: GitError.commandFailed(errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    continuation.resume(returning: ())
                }
            }
            do {
                try task.run()
                if let data = patch.data(using: .utf8) {
                    stdin.fileHandleForWriting.write(data)
                }
                stdin.fileHandleForWriting.closeFile()
            } catch {
                continuation.resume(throwing: GitError.gitNotFound)
            }
        }
    }

    private func patchString(for hunk: DiffHunk, filePath: String) -> String {
        let linesStr = hunk.lines.map { line in
            switch line.type {
            case .added: return "+\(line.text)"
            case .removed: return "-\(line.text)"
            case .context: return " \(line.text)"
            case .header: return line.text
            case .conflictMarker: return " \(line.text)"
            }
        }.joined(separator: "\n")
        return "--- a/\(filePath)\n+++ b/\(filePath)\n\(hunk.header)\n\(linesStr)\n"
    }

    private func patchString(for hunk: DiffHunk, selectedLines: [DiffLine], filePath: String) -> String {
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

        let pattern = #"@@ -(\d+)(?:(\d+))? \+(\d+)(?:(\d+))? @@"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: hunk.header, range: NSRange(hunk.header.startIndex..., in: hunk.header)) else {
            return patchString(for: hunk, filePath: filePath)
        }

        let oldStart = Int(hunk.header[Range(match.range(at: 1), in: hunk.header)!])!
        let newStart = Int(hunk.header[Range(match.range(at: 3), in: hunk.header)!])!

        let newHeader = "@@ -\(oldStart),\(oldCount) +\(newStart),\(newCount) @@"
        let linesStr = filteredLines.joined(separator: "\n")
        return "--- a/\(filePath)\n+++ b/\(filePath)\n\(newHeader)\n\(linesStr)\n"
    }
}
