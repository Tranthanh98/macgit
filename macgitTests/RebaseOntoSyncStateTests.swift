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
final class RebaseOntoSyncStateTests: XCTestCase {
    func testRebaseOntoMovesCurrentHeadOntoTargetTip() async throws {
        let repoURL = try makeRepoWithDivergedFeatureBranch()
        let syncState = SyncState()
        let undoManager = GitUndoManager()
        let initialHead = try await GitStatusService.shared.tipHash(for: "feature", in: repoURL)
        guard let initialHead else {
            XCTFail("Expected an initial feature tip")
            return
        }

        await syncState.performRebaseOnto(
            branch: "main",
            repositoryURL: repoURL,
            undoManager: undoManager
        )

        let rebasedHead = try await GitStatusService.shared.tipHash(for: "feature", in: repoURL)
        let mainTip = try await GitStatusService.shared.tipHash(for: "main", in: repoURL)
        guard let rebasedHead, let mainTip else {
            XCTFail("Expected rebased feature tip and main tip")
            return
        }
        XCTAssertNotEqual(rebasedHead, initialHead)
        let commitMessage = tipSubject(of: rebasedHead, in: repoURL)
        XCTAssertTrue(
            commitMessage.contains("feature") || commitMessage.contains("Feature"),
            "Expected rebased tip to retain the feature commit subject; got '\(commitMessage)'"
        )
        // The new feature tip should be a descendant of main.
        XCTAssertTrue(isAncestor(mainTip, of: rebasedHead, in: repoURL))

        let entries = await undoManager.undoStack
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.label ?? "", "Rebase onto main")
    }

    func testRebaseOntoWithNoChangeInHeadSkipsUndoRegistration() async throws {
        let repoURL = try makeRepoWithMainBranch()
        let syncState = SyncState()
        let undoManager = GitUndoManager()

        // main is already at main — rebasing onto itself is a no-op.
        await syncState.performRebaseOnto(
            branch: "main",
            repositoryURL: repoURL,
            undoManager: undoManager
        )

        let entries = await undoManager.undoStack
        XCTAssertTrue(entries.isEmpty, "Expected no undo entry for no-op rebase")
    }

    // MARK: - Helpers

    private func makeRepoWithMainBranch() throws -> URL {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-rebase-onto-\(UUID().uuidString)", isDirectory: true)
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
        // Move main forward with a new commit.
        let mainFile = repoURL.appendingPathComponent("main-only.txt")
        try "main update\n".write(to: mainFile, atomically: true, encoding: .utf8)
        try runGit(["add", "main-only.txt"], in: repoURL)
        try runGit(["commit", "-m", "main update"], in: repoURL)

        // Create feature from the previous main HEAD and add a feature commit.
        try runGit(["checkout", "-b", "feature", "HEAD~1"], in: repoURL)
        let featureFile = repoURL.appendingPathComponent("feature.txt")
        try "feature update\n".write(to: featureFile, atomically: true, encoding: .utf8)
        try runGit(["add", "feature.txt"], in: repoURL)
        try runGit(["commit", "-m", "Feature work"], in: repoURL)
        return repoURL
    }

    private func tipSubject(of commit: String, in repositoryURL: URL) -> String {
        runGitOutput(["log", "-1", "--format=%s", commit], in: repositoryURL)
    }

    private func isAncestor(_ ancestor: String, of descendant: String, in repositoryURL: URL) -> Bool {
        let result = runGitExit(["merge-base", "--is-ancestor", ancestor, descendant], in: repositoryURL)
        return result == 0
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

    private func runGitExit(_ arguments: [String], in repositoryURL: URL) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = arguments
        task.currentDirectoryURL = repositoryURL
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
        } catch {
            return -1
        }
        task.waitUntilExit()
        return task.terminationStatus
    }
}
