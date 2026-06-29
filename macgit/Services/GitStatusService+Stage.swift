//
//  GitStatusService+Stage.swift
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
        let patch = DiffPatchBuilder.patchString(for: hunk, filePath: file.path)
        try await applyPatch(patch, in: repositoryURL, cached: true)
    }

    func discard(hunk: DiffHunk, file: StatusFile, in repositoryURL: URL) async throws {
        guard file.status != .untracked else {
            throw GitError.commandFailed("Cannot discard hunk for untracked file")
        }
        let patch = DiffPatchBuilder.patchString(for: hunk, filePath: file.path)
        try await applyPatch(patch, in: repositoryURL, reverse: true)
    }

    func stage(lines: [DiffLine], hunk: DiffHunk, file: StatusFile, in repositoryURL: URL) async throws {
        guard file.status != .untracked else {
            throw GitError.commandFailed("Cannot stage lines for untracked file")
        }
        let patch = DiffPatchBuilder.patchString(for: hunk, selectedLines: lines, filePath: file.path)
        try await applyPatch(patch, in: repositoryURL, cached: true)
    }

    func discard(lines: [DiffLine], hunk: DiffHunk, file: StatusFile, in repositoryURL: URL) async throws {
        guard file.status != .untracked else {
            throw GitError.commandFailed("Cannot discard lines for untracked file")
        }
        let patch = DiffPatchBuilder.patchString(for: hunk, selectedLines: lines, filePath: file.path)
        try await applyPatch(patch, in: repositoryURL, reverse: true)
    }

    func unstage(hunk: DiffHunk, file: StatusFile, in repositoryURL: URL) async throws {
        let patch = DiffPatchBuilder.patchString(for: hunk, filePath: file.path)
        try await applyPatch(patch, in: repositoryURL, cached: true, reverse: true)
    }

    func unstage(lines: [DiffLine], hunk: DiffHunk, file: StatusFile, in repositoryURL: URL) async throws {
        let patch = DiffPatchBuilder.patchString(for: hunk, selectedLines: lines, filePath: file.path)
        try await applyPatch(patch, in: repositoryURL, cached: true, reverse: true)
    }

    // MARK: - Patch Helpers

    func applyPatch(_ patch: String, in repositoryURL: URL, cached: Bool = false, reverse: Bool = false) async throws {
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

}
