//
//  GitStatusService+Branch.swift
//  macgit
//

import Foundation

extension GitStatusService {
    func currentBranch(in repositoryURL: URL) async -> String? {
        let branch = (try? await runGit(arguments: ["branch", "--show-current"], in: repositoryURL))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let b = branch, !b.isEmpty else { return nil }
        return b
    }

    func localBranches(in repositoryURL: URL) async -> [String] {
        let output = (try? await runGit(arguments: ["branch", "--format=%(refname:short)"], in: repositoryURL)) ?? ""
        return output.split(separator: "\n").map { String($0) }.filter { !$0.isEmpty }
    }

    func upstreamBranch(for branch: String, in repositoryURL: URL) async -> String? {
        let upstream = (try? await runGit(arguments: ["rev-parse", "--abbrev-ref", "\(branch)@{upstream}"], in: repositoryURL))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let u = upstream, !u.isEmpty, !u.contains("fatal:") else { return nil }
        return u
    }

    func setUpstream(remote: String, branch: String, in repositoryURL: URL) async throws {
        _ = try await runGit(arguments: ["branch", "--set-upstream-to", "\(remote)/\(branch)", branch], in: repositoryURL)
    }

    func createBranch(name: String, checkout: Bool, commit: String?, in repositoryURL: URL) async throws -> String {
        if checkout {
            var arguments = ["checkout", "-b", name]
            if let commit = commit, !commit.isEmpty {
                arguments.append(commit)
            }
            return try await runGit(arguments: arguments, in: repositoryURL)
        } else {
            var arguments = ["branch", name]
            if let commit = commit, !commit.isEmpty {
                arguments.append(commit)
            }
            return try await runGit(arguments: arguments, in: repositoryURL)
        }
    }

    func deleteBranch(name: String, force: Bool, in repositoryURL: URL) async throws -> String {
        let flag = force ? "-D" : "-d"
        return try await runGit(arguments: ["branch", flag, name], in: repositoryURL)
    }

    func deleteRemoteBranch(remote: String, name: String, in repositoryURL: URL) async throws -> String {
        return try await runGit(arguments: ["push", remote, "--delete", name], in: repositoryURL)
    }
}
