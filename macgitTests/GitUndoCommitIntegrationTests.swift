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

final class GitUndoCommitIntegrationTests: XCTestCase {
    func testUndoCommitSoftResetRestoresStagedChanges() async throws {
        let repoURL = try makeTempRepo()
        let oldHead = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)
        try "changed\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "tracked.txt"], in: repoURL)
        try await GitStatusService.shared.commit(message: "change tracked", in: repoURL)
        let newHead = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)

        let executor = GitUndoExecutor()
        try await executor.execute(.resetHead(target: oldHead, mode: .soft, expectedHead: newHead), in: repoURL)

        let status = try await GitStatusService.shared.status(for: repoURL)
        XCTAssertTrue(status.staged.contains { $0.path == "tracked.txt" })
        XCTAssertEqual(try runGitOutput(["rev-parse", "HEAD"], in: repoURL), oldHead)
    }

    func testRedoCommitCreatesNewHeadFromRestoredIndex() async throws {
        let repoURL = try makeTempRepo()
        let oldHead = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)
        try "changed\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "tracked.txt"], in: repoURL)
        try await GitStatusService.shared.commit(message: "change tracked", in: repoURL)
        let newHead = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)

        let executor = GitUndoExecutor()
        try await executor.execute(.resetHead(target: oldHead, mode: .soft, expectedHead: newHead), in: repoURL)
        try await executor.execute(.commit(message: "change tracked", noVerify: false, signOff: false), in: repoURL)

        let redoneHead = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)
        XCTAssertNotEqual(redoneHead, oldHead)
        let status = try await GitStatusService.shared.status(for: repoURL)
        XCTAssertTrue(status.isEmpty)
    }

    private func makeTempRepo() throws -> URL {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-undo-commit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        try runGit(["init", "-b", "main"], in: repoURL)
        try runGit(["config", "user.name", "Mac Git Tests"], in: repoURL)
        try runGit(["config", "user.email", "tests@example.com"], in: repoURL)
        try "base\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "tracked.txt"], in: repoURL)
        try runGit(["commit", "-m", "initial"], in: repoURL)
        return repoURL
    }

    private func runGit(_ arguments: [String], in repositoryURL: URL) throws {
        _ = try runGitOutput(arguments, in: repositoryURL)
    }

    private func runGitOutput(_ arguments: [String], in repositoryURL: URL) throws -> String {
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
            let output = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "git failed"
            throw GitError.commandFailed(output)
        }
        return (String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
