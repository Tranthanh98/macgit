//
//  GitStatusService+Commit.swift
//  macgit
//

import Foundation

extension GitStatusService {
    func commit(message: String, in repositoryURL: URL, amend: Bool = false, noVerify: Bool = false, signOff: Bool = false) async throws {
        var arguments = ["commit", "-m", message]
        if amend { arguments.append("--amend") }
        if noVerify { arguments.append("--no-verify") }
        if signOff { arguments.append("--signoff") }
        _ = try await runGit(arguments: arguments, in: repositoryURL)
    }

    func gitUser(in repositoryURL: URL) async -> String? {
        let name = (try? await runGit(arguments: ["config", "user.name"], in: repositoryURL))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let email = (try? await runGit(arguments: ["config", "user.email"], in: repositoryURL))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let n = name, !n.isEmpty, let e = email, !e.isEmpty else { return nil }
        return "\(n) <\(e)>"
    }

    func recentCommits(limit: Int, in repositoryURL: URL) async -> [(hash: String, message: String)] {
        let output = (try? await runGit(arguments: ["log", "--oneline", "-\(limit)"], in: repositoryURL)) ?? ""
        return output.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            // Format: "<short-hash> <message>"
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
            guard let hash = parts.first else { return nil }
            let message = parts.count > 1 ? String(parts[1]) : ""
            return (hash: String(hash), message: message)
        }
    }

    func recentCommits(in repositoryURL: URL, count: Int = 10) async -> [(hash: String, message: String)] {
        let output = (try? await runGit(arguments: ["log", "--oneline", "-\(count)"], in: repositoryURL)) ?? ""
        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", maxSplits: 1)
            guard let hash = parts.first else { return nil }
            let message = parts.count > 1 ? String(parts[1]) : ""
            return (hash: String(hash), message: message)
        }
    }

    // MARK: - Commit History

    func commitHistory(allBranches: Bool, in repositoryURL: URL) async -> [Commit] {
        var arguments = ["log"]
        if allBranches {
            arguments.append("--all")
        }
        arguments.append(contentsOf: [
            "--format=%H%x00%P%x00%s%x00%an%x00%ae%x00%ad%x00%D",
            "--date=iso-strict",
            "-n", "500"
        ])
        let output = (try? await runGit(arguments: arguments, in: repositoryURL)) ?? ""
        return parseCommitLog(output)
    }

    func commitHistory(branch: String, in repositoryURL: URL) async -> [Commit] {
        let arguments = [
            "log", branch,
            "--format=%H%x00%P%x00%s%x00%an%x00%ae%x00%ad%x00%D",
            "--date=iso-strict",
            "-n", "500"
        ]

        let output = (try? await runGit(arguments: arguments, in: repositoryURL)) ?? ""
        return parseCommitLog(output)
    }

    func tipHash(for branch: String, in repositoryURL: URL) async -> String? {
        let output = (try? await runGit(arguments: ["rev-parse", branch], in: repositoryURL))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return output?.isEmpty == false ? output : nil
    }

    func aheadBehindCount(in repositoryURL: URL) async -> (ahead: Int, behind: Int) {
        let aheadOutput = (try? await runGit(arguments: ["rev-list", "--count", "@{upstream}..HEAD"], in: repositoryURL))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let behindOutput = (try? await runGit(arguments: ["rev-list", "--count", "HEAD..@{upstream}"], in: repositoryURL))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let ahead = Int(aheadOutput ?? "0") ?? 0
        let behind = Int(behindOutput ?? "0") ?? 0
        return (ahead: ahead, behind: behind)
    }

    private func parseCommitLog(_ raw: String) -> [Commit] {
        let dateFormatter = ISO8601DateFormatter()
        var commits: [Commit] = []
        for line in raw.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: "\u{0000}", omittingEmptySubsequences: false)
            guard parts.count >= 6 else { continue }
            let hash = String(parts[0])
            let parentStr = String(parts[1])
            let parents = parentStr.isEmpty ? [] : parentStr.split(separator: " ").map { String($0) }
            let message = String(parts[2])
            let author = String(parts[3])
            let email = String(parts[4])
            let dateStr = String(parts[5])
            let refsPart = parts.count > 6 ? String(parts[6]) : ""
            let refs = refsPart.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let date = dateFormatter.date(from: dateStr) ?? Date()
            commits.append(Commit(hash: hash, parents: parents, message: message, author: author, email: email, date: date, refs: refs))
        }
        return commits
    }
}
