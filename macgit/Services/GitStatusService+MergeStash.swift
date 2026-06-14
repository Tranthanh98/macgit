//
//  GitStatusService+MergeStash.swift
//  macgit
//

import Foundation

extension GitStatusService {
    func merge(branch: String, options: MergeOptions, in repositoryURL: URL) async throws -> String {
        var arguments = ["merge"]
        if options.noFastForward { arguments.append("--no-ff") }
        if options.squash { arguments.append("--squash") }
        if !options.squash && !options.message.isEmpty {
            arguments.append("-m")
            arguments.append(options.message)
        }
        arguments.append(branch)
        return try await runGit(arguments: arguments, in: repositoryURL)
    }

    func stash(options: StashOptions, in repositoryURL: URL) async throws {
        var arguments = ["stash", "push"]
        if options.keepIndex { arguments.append("--keep-index") }
        if !options.message.isEmpty {
            arguments.append("-m")
            arguments.append(options.message)
        }
        _ = try await runGit(arguments: arguments, in: repositoryURL)
    }

    func stashes(in repositoryURL: URL) async -> [StashEntry] {
        let output = (try? await runGit(arguments: ["stash", "list", "--format=%gd%x1f%gs"], in: repositoryURL)) ?? ""
        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\u{001f}", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }

            let ref = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ref.isEmpty else { return nil }

            let parsed = parseStashSummary(summary)
            return StashEntry(ref: ref, branchName: parsed.branchName, description: parsed.description)
        }
    }

    func applyStash(ref: String, dropAfterApplying: Bool = false, in repositoryURL: URL) async throws {
        let command = dropAfterApplying ? "pop" : "apply"
        _ = try await runGit(arguments: ["stash", command, ref], in: repositoryURL)
    }

    func dropStash(ref: String, in repositoryURL: URL) async throws {
        _ = try await runGit(arguments: ["stash", "drop", ref], in: repositoryURL)
    }

    private func parseStashSummary(_ summary: String) -> (branchName: String, description: String) {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)

        let prefix: String
        if trimmed.hasPrefix("WIP on ") {
            prefix = "WIP on "
        } else if trimmed.hasPrefix("On ") {
            prefix = "On "
        } else {
            return ("", trimmed)
        }

        let remainder = String(trimmed.dropFirst(prefix.count))
        guard let colonIndex = remainder.firstIndex(of: ":") else {
            return (remainder.trimmingCharacters(in: .whitespacesAndNewlines), "")
        }

        let branchName = String(remainder[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptionStart = remainder.index(after: colonIndex)
        let description = String(remainder[descriptionStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (branchName, description)
    }
}
