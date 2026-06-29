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

final class GitUndoStashSaveDropTests: XCTestCase {
    func testUndoStashSaveAppliesAndDropsSavedStash() async throws {
        let repoURL = try makeTempRepo()
        try "changed\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try await GitStatusService.shared.stash(options: GitStatusService.StashOptions(message: "save undo"), in: repoURL)
        let support = GitStashUndoSupport()
        let hash = try await support.hash(for: "stash@{0}", in: repoURL)

        let executor = GitUndoExecutor()

        try await executor.execute(.stashApplyAndDrop(hash: hash), in: repoURL)

        let content = try String(contentsOf: repoURL.appendingPathComponent("tracked.txt"), encoding: .utf8)
        XCTAssertEqual(content, "changed\n")
        let stashes = await GitStatusService.shared.stashes(in: repoURL)
        XCTAssertTrue(stashes.isEmpty)
    }

    func testUndoStashDropRestoresStashEntry() async throws {
        let repoURL = try makeTempRepo()
        try "changed\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try await GitStatusService.shared.stash(options: GitStatusService.StashOptions(message: "drop undo"), in: repoURL)
        let support = GitStashUndoSupport()
        let hash = try await support.hash(for: "stash@{0}", in: repoURL)
        let summary = try await support.summary(for: "stash@{0}", in: repoURL)
        try await GitStatusService.shared.dropStash(ref: "stash@{0}", in: repoURL)

        let executor = GitUndoExecutor()
        try await executor.execute(.stashStore(commit: hash, message: summary), in: repoURL)

        let stashes = await GitStatusService.shared.stashes(in: repoURL)
        XCTAssertEqual(stashes.count, 1)
        let restoredHash = try await support.hash(for: "stash@{0}", in: repoURL)
        XCTAssertEqual(restoredHash, hash)
    }

    private func makeTempRepo() throws -> URL {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-undo-stash-save-drop-\(UUID().uuidString)", isDirectory: true)
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
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = arguments
        task.currentDirectoryURL = repositoryURL
        let stderr = Pipe()
        task.standardError = stderr
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            let output = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "git failed"
            throw GitError.commandFailed(output)
        }
    }
}
