//
//  GitStashUndoSupport.swift
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

struct GitStashUndoSupport {
    private let runner: any GitCommandRunning

    init(runner: (any GitCommandRunning)? = nil) {
        self.runner = runner ?? GitStatusService.shared
    }

    func hash(for ref: String, in repositoryURL: URL) async throws -> String {
        try await runner.runGit(arguments: ["rev-parse", "\(ref)^{commit}"], in: repositoryURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func summary(for ref: String, in repositoryURL: URL) async throws -> String {
        try await runner.runGit(arguments: ["stash", "list", "--format=%gd%x1f%gs"], in: repositoryURL)
            .split(separator: "\n")
            .compactMap { line -> String? in
                let parts = line.split(separator: "\u{001f}", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2, String(parts[0]) == ref else {
                    return nil
                }
                return String(parts[1])
            }
            .first ?? "Restored stash"
    }

    func ref(matchingHash hash: String, in repositoryURL: URL) async throws -> String? {
        let refs = try await runner.runGit(arguments: ["stash", "list", "--format=%gd"], in: repositoryURL)
            .split(separator: "\n")
            .map { String($0) }

        for ref in refs {
            let refHash = try await self.hash(for: ref, in: repositoryURL)
            if refHash == hash {
                return ref
            }
        }

        return nil
    }

    func dropStash(matchingHash hash: String, in repositoryURL: URL) async throws {
        guard let ref = try await ref(matchingHash: hash, in: repositoryURL) else {
            throw GitError.commandFailed("Could not find stash entry with hash \(hash).")
        }

        _ = try await runner.runGit(arguments: ["stash", "drop", ref], in: repositoryURL)
    }

    func isWorkingTreeClean(in repositoryURL: URL) async throws -> Bool {
        let output = try await runner.runGit(
            arguments: ["status", "--porcelain", "--untracked-files=all"],
            in: repositoryURL
        )
        return output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func stashHasUntrackedPayload(ref: String, in repositoryURL: URL) async throws -> Bool {
        let output = try await runner.runGit(
            arguments: ["stash", "show", "--only-untracked", "--name-only", ref],
            in: repositoryURL
        )
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
