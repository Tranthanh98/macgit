//
//  GitStashUndoSupport.swift
//  macgit
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
}
