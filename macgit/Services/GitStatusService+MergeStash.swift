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
}
