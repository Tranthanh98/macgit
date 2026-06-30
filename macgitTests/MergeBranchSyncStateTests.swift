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
import XCTest
@testable import macgit

@MainActor
final class MergeBranchSyncStateTests: XCTestCase {
    func testMergeBranchIntoCurrentFastForwards() async throws {
        let repoURL = try makeRepoWithDivergedFeatureBranch()
        let syncState = SyncState()

        // main is checked out by default; merge feature into main.
        await syncState.performMerge(
            branch: "feature",
            options: GitStatusService.MergeOptions(),
            repositoryURL: repoURL
        )

        let mainTip = try await GitStatusService.shared.tipHash(for: "main", in: repoURL)
        let featureTip = try await GitStatusService.shared.tipHash(for: "feature", in: repoURL)
        guard let mainTip, let featureTip else {
            XCTFail("Expected main and feature tips")
            return
        }
        XCTAssertEqual(mainTip, featureTip, "main should fast-forward to feature")
    }

    func testMergeBranchIntoCurrentCreatesMergeCommitWhenNotFastForward() async throws {
        let repoURL = try makeRepoWithDivergedBranches()
        let syncState = SyncState()

        await syncState.performMerge(
            branch: "feature",
            options: GitStatusService.MergeOptions(),
            repositoryURL: repoURL
        )

        let mainTip = try await GitStatusService.shared.tipHash(for: "main", in: repoURL)
        let featureTip = try await GitStatusService.shared.tipHash(for: "feature", in: repoURL)
        guard let mainTip, let featureTip else {
            XCTFail("Expected main and feature tips")
            return
        }
        XCTAssertNotEqual(mainTip, featureTip, "main tip should differ from feature tip when merge commit is created")
        let parents = try parents(of: mainTip, in: repoURL)
        XCTAssertEqual(parents.count, 2, "Merge commit should have two parents")
        XCTAssertTrue(parents.contains(featureTip), "Merge commit should include feature tip as a parent")
    }

    // MARK: - Helpers

    private func makeRepoWithMainBranch() throws -> URL {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-merge-branch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        try runGit(["init", "-b", "main"], in: repoURL)
        try runGit(["config", "user.name", "Mac Git Tests"], in: repoURL)
        try runGit(["config", "user.email", "tests@example.com"], in: repoURL)
        let file = repoURL.appendingPathComponent("tracked.txt")
        try "base\n".write(to: file, atomically: true, encoding: .utf8)
        try runGit(["add", "tracked.txt"], in: repoURL)
        try runGit(["commit", "-m", "initial"], in: repoURL)
        return repoURL
    }

    private func makeRepoWithDivergedFeatureBranch() throws -> URL {
        let repoURL = try makeRepoWithMainBranch()
        try runGit(["checkout", "-b", "feature"], in: repoURL)
        let featureFile = repoURL.appendingPathComponent("feature.txt")
        try "feature update\n".write(to: featureFile, atomically: true, encoding: .utf8)
        try runGit(["add", "feature.txt"], in: repoURL)
        try runGit(["commit", "-m", "Feature work"], in: repoURL)
        try runGit(["checkout", "main"], in: repoURL)
        return repoURL
    }

    private func makeRepoWithDivergedBranches() throws -> URL {
        let repoURL = try makeRepoWithMainBranch()
        // Move main forward so it cannot fast-forward to feature.
        let mainFile = repoURL.appendingPathComponent("main-only.txt")
        try "main update\n".write(to: mainFile, atomically: true, encoding: .utf8)
        try runGit(["add", "main-only.txt"], in: repoURL)
        try runGit(["commit", "-m", "main update"], in: repoURL)

        try runGit(["checkout", "-b", "feature", "HEAD~1"], in: repoURL)
        let featureFile = repoURL.appendingPathComponent("feature.txt")
        try "feature update\n".write(to: featureFile, atomically: true, encoding: .utf8)
        try runGit(["add", "feature.txt"], in: repoURL)
        try runGit(["commit", "-m", "Feature work"], in: repoURL)
        try runGit(["checkout", "main"], in: repoURL)
        return repoURL
    }

    private func parents(of commit: String, in repositoryURL: URL) throws -> [String] {
        let output = runGitOutput(["log", "-1", "--format=%P", commit], in: repositoryURL)
        return output.split(separator: " ").map { String($0) }
    }

    @discardableResult
    private func runGit(_ arguments: [String], in repositoryURL: URL) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = arguments
        task.currentDirectoryURL = repositoryURL

        let stdout = Pipe()
        let stderr = Pipe()
        task.standardOutput = stdout
        task.standardError = stderr

        try task.run()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            let outputData = stderr.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? "git failed"
            XCTFail("git \(arguments.joined(separator: " ")) failed: \(output)")
        }
        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: outputData, encoding: .utf8) ?? ""
    }

    private func runGitOutput(_ arguments: [String], in repositoryURL: URL) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = arguments
        task.currentDirectoryURL = repositoryURL

        let stdout = Pipe()
        let stderr = Pipe()
        task.standardOutput = stdout
        task.standardError = stderr

        do {
            try task.run()
        } catch {
            return ""
        }
        task.waitUntilExit()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
