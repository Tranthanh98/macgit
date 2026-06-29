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

final class GitRemoteUndoSupportTests: XCTestCase {
    func testRemoteBranchHashCanBeReadFromBareRemote() async throws {
        let fixture = try makeLocalRemoteFixture()
        let support = GitRemoteUndoSupport()

        let hash = try await support.remoteHash(remote: "origin", branch: "main", in: fixture.cloneURL)

        XCTAssertEqual(hash, fixture.mainHash)
    }

    func testRemoteBranchHashReturnsNilForMissingBranch() async throws {
        let fixture = try makeLocalRemoteFixture()
        let support = GitRemoteUndoSupport()

        let hash = try await support.remoteHash(remote: "origin", branch: "missing", in: fixture.cloneURL)

        XCTAssertNil(hash)
    }

    private func makeLocalRemoteFixture() throws -> (remoteURL: URL, cloneURL: URL, mainHash: String) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-remote-undo-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = root.appendingPathComponent("source", isDirectory: true)
        let remoteURL = root.appendingPathComponent("remote.git", isDirectory: true)
        let cloneURL = root.appendingPathComponent("clone", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try runGit(["init", "-b", "main"], in: sourceURL)
        try runGit(["config", "user.name", "Mac Git Tests"], in: sourceURL)
        try runGit(["config", "user.email", "tests@example.com"], in: sourceURL)
        try "base\n".write(to: sourceURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "tracked.txt"], in: sourceURL)
        try runGit(["commit", "-m", "initial"], in: sourceURL)
        let mainHash = try runGitOutput(["rev-parse", "HEAD"], in: sourceURL)
        try runGit(["init", "--bare", remoteURL.path], in: root)
        try runGit(["remote", "add", "origin", remoteURL.path], in: sourceURL)
        try runGit(["push", "-u", "origin", "main"], in: sourceURL)
        try runGit(["clone", remoteURL.path, cloneURL.path], in: root)
        return (remoteURL, cloneURL, mainHash)
    }

    private func runGit(_ arguments: [String], in directory: URL) throws {
        _ = try runGitOutput(arguments, in: directory)
    }

    private func runGitOutput(_ arguments: [String], in directory: URL) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = arguments
        task.currentDirectoryURL = directory
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
