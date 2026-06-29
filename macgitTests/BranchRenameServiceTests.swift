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

final class BranchRenameServiceTests: XCTestCase {
    func testRenameBranchMovesTheLocalRef() async throws {
        let repoURL = try makeRepoWithMainBranch()

        try await GitStatusService.shared.renameBranch(
            from: "main",
            to: "trunk",
            in: repoURL
        )

        let branches = await GitStatusService.shared.localBranches(in: repoURL)
        XCTAssertTrue(branches.contains("trunk"))
        XCTAssertFalse(branches.contains("main"))
    }

    func testRenameBranchKeepsTheCommitTip() async throws {
        let repoURL = try makeRepoWithMainBranch()
        let originalTip = try await GitStatusService.shared.tipHash(for: "main", in: repoURL)

        try await GitStatusService.shared.renameBranch(
            from: "main",
            to: "trunk",
            in: repoURL
        )

        let renamedTip = try await GitStatusService.shared.tipHash(for: "trunk", in: repoURL)
        XCTAssertEqual(renamedTip, originalTip)
    }

    func testRenameBranchOnCheckedOutBranchUpdatesCurrentBranch() async throws {
        let repoURL = try makeRepoWithMainBranch()

        try await GitStatusService.shared.renameBranch(
            from: "main",
            to: "trunk",
            in: repoURL
        )

        let current = await GitStatusService.shared.currentBranch(in: repoURL)
        XCTAssertEqual(current, "trunk")
    }

    func testRenameBranchCollisionsWithExistingNameThrows() async throws {
        let repoURL = try makeRepoWithMainBranch()
        try runGit(["checkout", "-b", "feature"], in: repoURL)
        try runGit(["checkout", "main"], in: repoURL)

        do {
            try await GitStatusService.shared.renameBranch(
                from: "main",
                to: "feature",
                in: repoURL
            )
            XCTFail("Expected rename to throw on collision")
        } catch {
            // Expected
        }

        let branches = await GitStatusService.shared.localBranches(in: repoURL)
        XCTAssertTrue(branches.contains("main"))
        XCTAssertTrue(branches.contains("feature"))
    }

    func testUndoExecutorRenameRoundTripRestoresOriginalName() async throws {
        let runner = RecordingGitRunner()
        let executor = GitUndoExecutor(runner: runner)
        let repoURL = URL(fileURLWithPath: "/tmp/repo")

        try await executor.execute(
            .renameLocalBranch(from: "main", to: "trunk"),
            in: repoURL
        )

        let calls = await runner.recordedCalls()
        XCTAssertEqual(calls, [
            GitCommandCall(
                arguments: ["branch", "-m", "main", "trunk"],
                directory: repoURL
            )
        ])
    }

    // MARK: - Helpers

    private func makeRepoWithMainBranch() throws -> URL {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-branch-rename-\(UUID().uuidString)", isDirectory: true)
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

    private func runGit(_ arguments: [String], in repositoryURL: URL) throws {
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
    }
}

private struct GitCommandCall: Equatable {
    let arguments: [String]
    let directory: URL
}

private actor RecordingGitRunner: GitCommandRunning {
    private var calls: [GitCommandCall] = []

    func runGit(arguments: [String], in directory: URL) async throws -> String {
        calls.append(GitCommandCall(arguments: arguments, directory: directory))
        return ""
    }

    func recordedCalls() -> [GitCommandCall] {
        calls
    }
}
