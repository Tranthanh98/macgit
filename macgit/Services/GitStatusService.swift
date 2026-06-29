//
//  GitStatusService.swift
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

actor GitStatusService {
    static let shared = GitStatusService()

    private init() {}

    func gitExecutable() -> String {
        // Prefer system git, fallback to /usr/bin/git
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["git"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        } catch {
            // fallthrough
        }
        return "/usr/bin/git"
    }

    func runGit(arguments: [String], in directory: URL) async throws -> String {
        let data = try await runGitRaw(arguments: arguments, in: directory)
        return String(data: data, encoding: .utf8) ?? ""
    }

    func runGitRaw(arguments: [String], in directory: URL) async throws -> Data {
        let executable = gitExecutable()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        task.currentDirectoryURL = directory
        task.environment = ProcessInfo.processInfo.environment

        let stdout = Pipe()
        let stderr = Pipe()
        task.standardOutput = stdout
        task.standardError = stderr

        return try await withCheckedThrowingContinuation { continuation in
            task.terminationHandler = { process in
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errData, encoding: .utf8) ?? ""

                if process.terminationStatus != 0 {
                    let output = String(data: outData, encoding: .utf8) ?? ""
                    let message = errorOutput.isEmpty ? output : errorOutput
                    continuation.resume(throwing: GitError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    continuation.resume(returning: outData)
                }
            }

            do {
                try task.run()
            } catch {
                continuation.resume(throwing: GitError.gitNotFound)
            }
        }
    }

    struct PushOptions {
        var remote: String = "origin"
        var branches: [String] = []
        var branchMappings: [String: String] = [:] // local branch -> remote branch name
        var pushTags: Bool = false
    }

    struct PullOptions {
        var commitMerged: Bool = true
        var includeMessages: Bool = true
        var noFastForward: Bool = false
        var rebaseInstead: Bool = false
    }

    struct MergeOptions {
        var noFastForward: Bool = false
        var squash: Bool = false
        var message: String = ""
    }

    struct StashOptions {
        var message: String = ""
        var keepIndex: Bool = false
    }

    struct FetchOptions {
        var fetchAllRemotes: Bool = true
        var prune: Bool = false
        var fetchTags: Bool = false
    }

    enum ConflictResolution {
        case ours, theirs
    }
}
