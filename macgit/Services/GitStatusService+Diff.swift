//
//  GitStatusService+Diff.swift
//  macgit
//

import Foundation

extension GitStatusService {
    func diff(for file: String, in commit: String, in repositoryURL: URL) async -> [DiffHunk] {
        let output = (try? await runGit(arguments: ["show", "--no-color", "-p", commit, "--", file], in: repositoryURL)) ?? ""
        // Strip the commit header; diff starts at "diff --git"
        guard let diffStart = output.range(of: "diff --git") else { return [] }
        let diffText = String(output[diffStart.lowerBound...])
        return DiffParser.parse(diffText)
    }

    func diff(for file: StatusFile, in repositoryURL: URL) async throws -> [DiffHunk] {
        // Untracked file → read directly and show all lines as added (green)
        if file.status == .untracked {
            let fileURL = repositoryURL.appendingPathComponent(file.path)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
            let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
            let diffLines = lines.enumerated().map { index, line in
                DiffLine(oldLineNumber: nil, newLineNumber: index + 1, text: String(line), type: .added)
            }
            return [DiffHunk(header: "@@ -0,0 +1,\(lines.count) @@", lines: diffLines)]
        }

        // Deleted file → get old content from HEAD and show all lines as removed (red)
        if file.status == .deleted {
            let output = try await runGit(arguments: ["show", "HEAD:\(file.path)"], in: repositoryURL)
            let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
            let diffLines = lines.enumerated().map { index, line in
                DiffLine(oldLineNumber: index + 1, newLineNumber: nil, text: String(line), type: .removed)
            }
            return [DiffHunk(header: "@@ -1,\(lines.count) +0,0 @@", lines: diffLines)]
        }

        // Normal diff for modified/renamed/staged files
        let isStaged = file.status == .staged || file.status == .added || file.status == .renamed
        var arguments = ["diff", "--no-color", "-U3"]
        if isStaged {
            arguments.append("--cached")
        }
        arguments.append("--")
        arguments.append(file.path)

        let output = try await runGit(arguments: arguments, in: repositoryURL)
        return DiffParser.parse(output)
    }

    func changedFiles(in commit: String, in repositoryURL: URL) async -> [CommitFileChange] {
        let output = (try? await runGit(arguments: ["show", "--name-status", "--format=", commit], in: repositoryURL)) ?? ""
        var changes: [CommitFileChange] = []
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: "\t", maxSplits: 1)
            guard parts.count >= 2 else { continue }
            let statusCode = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let path = String(parts[1]).trimmingCharacters(in: .whitespaces)

            let status: CommitFileStatus
            switch statusCode.prefix(1) {
            case "A": status = .added
            case "M": status = .modified
            case "D": status = .deleted
            case "R": status = .renamed
            case "C": status = .copied
            default: status = .modified
            }
            changes.append(CommitFileChange(path: path, status: status))
        }
        return changes
    }

    func checkoutCommit(_ commit: String, in repositoryURL: URL) async throws {
        _ = try await runGit(arguments: ["checkout", commit], in: repositoryURL)
    }

    func cherryPickCommit(_ commit: String, in repositoryURL: URL) async throws {
        _ = try await runGit(arguments: ["cherry-pick", commit], in: repositoryURL)
    }
}
