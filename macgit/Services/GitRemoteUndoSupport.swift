//
//  GitRemoteUndoSupport.swift
//  macgit
//

import Foundation

struct GitRemoteUndoSupport {
    private let runner: any GitCommandRunning

    init(runner: (any GitCommandRunning)? = nil) {
        self.runner = runner ?? GitStatusService.shared
    }

    func remoteHash(remote: String, branch: String, in repositoryURL: URL) async throws -> String? {
        let output = try await runner.runGit(arguments: ["ls-remote", remote, "refs/heads/\(branch)"], in: repositoryURL)
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.split(separator: "\t").first.map(String.init)
    }
}
