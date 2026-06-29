//
//  GitUndoDiscardRemoveIntegrationTests.swift
//  macgitTests
//

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

final class GitUndoDiscardRemoveIntegrationTests: XCTestCase {
    func testSnapshotRestoresDiscardedTrackedFile() async throws {
        let repoURL = try makeTempRepo()
        let fileURL = repoURL.appendingPathComponent("tracked.txt")
        try "changed\n".write(to: fileURL, atomically: true, encoding: .utf8)
        let store = GitFileUndoSnapshotStore()
        let snapshot = try store.capture(paths: ["tracked.txt"], in: repoURL)
        let file = StatusFile(path: "tracked.txt", status: .modified, originalPath: nil)
        try await GitStatusService.shared.discard(file: file, in: repoURL)

        try store.restore(snapshotID: snapshot.id, in: repoURL)

        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "changed\n")
    }

    func testSnapshotRestoresRemovedUntrackedFile() async throws {
        let repoURL = try makeTempRepo()
        let fileURL = repoURL.appendingPathComponent("new.txt")
        try "new\n".write(to: fileURL, atomically: true, encoding: .utf8)
        let store = GitFileUndoSnapshotStore()
        let snapshot = try store.capture(paths: ["new.txt"], in: repoURL)
        let file = StatusFile(path: "new.txt", status: .untracked, originalPath: nil)
        try await GitStatusService.shared.remove(file: file, in: repoURL)

        try store.restore(snapshotID: snapshot.id, in: repoURL)

        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "new\n")
    }

    private func makeTempRepo() throws -> URL {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-undo-discard-remove-\(UUID().uuidString)", isDirectory: true)
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
