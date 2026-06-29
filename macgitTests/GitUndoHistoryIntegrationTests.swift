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

final class GitUndoHistoryIntegrationTests: XCTestCase {
    func testCherryPickUndoResetsToOldHead() async throws {
        let repoURL = try makeRepoWithFeatureCommit()
        let oldHead = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)
        let featureHead = try runGitOutput(["rev-parse", "feature"], in: repoURL)
        let executor = GitUndoExecutor()

        try await executor.execute(.cherryPick(commit: featureHead), in: repoURL)
        let newHead = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)
        try await executor.execute(.resetHead(target: oldHead, mode: .hard, expectedHead: newHead), in: repoURL)

        XCTAssertEqual(try runGitOutput(["rev-parse", "HEAD"], in: repoURL), oldHead)
    }

    func testBatchCherryPickRedoReappliesAllCommits() async throws {
        let repoURL = try makeRepoWithTwoFeatureCommits()
        let oldHead = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)
        let firstFeatureHead = try runGitOutput(["rev-parse", "feature~1"], in: repoURL)
        let secondFeatureHead = try runGitOutput(["rev-parse", "feature"], in: repoURL)
        let executor = GitUndoExecutor()

        try await executor.execute(
            .cherryPickCommits(commits: [firstFeatureHead, secondFeatureHead]),
            in: repoURL
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: repoURL.appendingPathComponent("feature-one.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: repoURL.appendingPathComponent("feature-two.txt").path))
        XCTAssertEqual(
            try runGitOutput(["log", "--format=%s", "-2"], in: repoURL)
                .components(separatedBy: "\n"),
            ["feature two", "feature one"]
        )

        let newHead = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)
        try await executor.execute(.resetHead(target: oldHead, mode: .hard, expectedHead: newHead), in: repoURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repoURL.appendingPathComponent("feature-one.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: repoURL.appendingPathComponent("feature-two.txt").path))

        try await executor.execute(
            .cherryPickCommits(commits: [firstFeatureHead, secondFeatureHead]),
            in: repoURL
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: repoURL.appendingPathComponent("feature-one.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: repoURL.appendingPathComponent("feature-two.txt").path))
        XCTAssertEqual(
            try runGitOutput(["log", "--format=%s", "-2"], in: repoURL)
                .components(separatedBy: "\n"),
            ["feature two", "feature one"]
        )
    }

    func testCherryPickOntoNonCurrentBranchUsesTemporaryWorktreeAndKeepsMainCheckout() async throws {
        let repoURL = try makeRepoWithTwoFeatureCommits()
        let mainHead = try runGitOutput(["rev-parse", "main"], in: repoURL)
        let featureHead = try runGitOutput(["rev-parse", "feature"], in: repoURL)
        let firstFeatureHead = try runGitOutput(["rev-parse", "feature~1"], in: repoURL)
        try runGit(["branch", "release"], in: repoURL)

        try await GitStatusService.shared.cherryPickCommits(
            [firstFeatureHead, featureHead],
            onto: "release",
            in: repoURL
        )

        XCTAssertEqual(try runGitOutput(["branch", "--show-current"], in: repoURL), "main")
        XCTAssertEqual(try runGitOutput(["rev-parse", "HEAD"], in: repoURL), mainHead)
        XCTAssertEqual(try runGitOutput(["status", "--porcelain"], in: repoURL), "")
        XCTAssertFalse(FileManager.default.fileExists(atPath: repoURL.appendingPathComponent("feature-one.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: repoURL.appendingPathComponent("feature-two.txt").path))
        XCTAssertNil(try worktreePath(for: "release", in: repoURL))
        XCTAssertEqual(
            try runGitOutput(["log", "--format=%s", "-2", "release"], in: repoURL)
                .components(separatedBy: "\n"),
            ["feature two", "feature one"]
        )
        XCTAssertEqual(try runGitOutput(["rev-parse", "main"], in: repoURL), mainHead)
        XCTAssertEqual(try runGitOutput(["rev-parse", "feature"], in: repoURL), featureHead)
    }

    func testCherryPickOntoCurrentBranchUsesCurrentWorkingCopy() async throws {
        let repoURL = try makeRepoWithFeatureCommit()
        let featureHead = try runGitOutput(["rev-parse", "feature"], in: repoURL)

        let location = try await GitStatusService.shared.cherryPickCommits(
            [featureHead],
            onto: "main",
            in: repoURL
        )

        XCTAssertEqual(location, .currentWorkingCopy)
        XCTAssertEqual(try runGitOutput(["branch", "--show-current"], in: repoURL), "main")
        XCTAssertTrue(FileManager.default.fileExists(atPath: repoURL.appendingPathComponent("feature.txt").path))
    }

    func testCherryPickOntoNonCurrentBranchUsesExistingWorktree() async throws {
        let repoURL = try makeRepoWithFeatureCommit()
        let mainHead = try runGitOutput(["rev-parse", "main"], in: repoURL)
        let featureHead = try runGitOutput(["rev-parse", "feature"], in: repoURL)
        let worktreeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-existing-release-\(UUID().uuidString)", isDirectory: true)
        try runGit(["branch", "release"], in: repoURL)
        try runGit(["worktree", "add", worktreeURL.path, "release"], in: repoURL)
        defer {
            try? runGit(["worktree", "remove", "--force", worktreeURL.path], in: repoURL)
        }

        try await GitStatusService.shared.cherryPickCommits(
            [featureHead],
            onto: "release",
            in: repoURL
        )

        XCTAssertEqual(try runGitOutput(["branch", "--show-current"], in: repoURL), "main")
        XCTAssertEqual(try runGitOutput(["rev-parse", "HEAD"], in: repoURL), mainHead)
        XCTAssertEqual(try runGitOutput(["status", "--porcelain"], in: repoURL), "")
        XCTAssertFalse(FileManager.default.fileExists(atPath: repoURL.appendingPathComponent("feature.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: worktreeURL.appendingPathComponent("feature.txt").path))
        XCTAssertEqual(try worktreePath(for: "release", in: repoURL)?.standardizedFileURL, worktreeURL.standardizedFileURL)
    }

    func testCherryPickConflictKeepsTemporaryWorktreeAndReportsPath() async throws {
        let repoURL = try makeRepoWithConflictingFeatureCommit()
        let mainHead = try runGitOutput(["rev-parse", "main"], in: repoURL)
        let featureHead = try runGitOutput(["rev-parse", "feature"], in: repoURL)
        try runGit(["branch", "release"], in: repoURL)
        var retainedWorktreeURL: URL?
        defer {
            if let retainedWorktreeURL {
                try? runGit(["cherry-pick", "--abort"], in: retainedWorktreeURL)
                try? runGit(["worktree", "remove", "--force", retainedWorktreeURL.path], in: repoURL)
            }
        }

        do {
            try await GitStatusService.shared.cherryPickCommits(
                [featureHead],
                onto: "release",
                in: repoURL
            )
            XCTFail("cherry-pick should conflict")
        } catch {
            retainedWorktreeURL = try worktreePath(for: "release", in: repoURL)
            let worktreeURL = try XCTUnwrap(retainedWorktreeURL)
            let worktreeError = try XCTUnwrap(error as? GitCherryPickWorktreeError)
            XCTAssertNotEqual(worktreeURL.standardizedFileURL, repoURL.standardizedFileURL)
            XCTAssertEqual(
                worktreeError.path.resolvingSymlinksInPath(),
                worktreeURL.resolvingSymlinksInPath()
            )
            XCTAssertTrue(error.localizedDescription.contains(worktreeError.path.path))
            XCTAssertTrue(error.localizedDescription.localizedCaseInsensitiveContains("conflict"))
            XCTAssertFalse(try runGitOutput(["rev-parse", "--verify", "CHERRY_PICK_HEAD"], in: worktreeURL).isEmpty)
        }

        XCTAssertEqual(try runGitOutput(["branch", "--show-current"], in: repoURL), "main")
        XCTAssertEqual(try runGitOutput(["rev-parse", "HEAD"], in: repoURL), mainHead)
        XCTAssertEqual(try runGitOutput(["status", "--porcelain"], in: repoURL), "")
        XCTAssertEqual(try String(contentsOf: repoURL.appendingPathComponent("tracked.txt"), encoding: .utf8), "main\n")
    }

    func testCherryPickConflictKeepsExistingWorktreeAndReportsPath() async throws {
        let repoURL = try makeRepoWithConflictingFeatureCommit()
        let mainHead = try runGitOutput(["rev-parse", "main"], in: repoURL)
        let featureHead = try runGitOutput(["rev-parse", "feature"], in: repoURL)
        let worktreeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-existing-conflict-\(UUID().uuidString)", isDirectory: true)
        try runGit(["branch", "release"], in: repoURL)
        try runGit(["worktree", "add", worktreeURL.path, "release"], in: repoURL)
        defer {
            try? runGit(["cherry-pick", "--abort"], in: worktreeURL)
            try? runGit(["worktree", "remove", "--force", worktreeURL.path], in: repoURL)
        }

        do {
            try await GitStatusService.shared.cherryPickCommits(
                [featureHead],
                onto: "release",
                in: repoURL
            )
            XCTFail("cherry-pick should conflict")
        } catch {
            let worktreeError = try XCTUnwrap(error as? GitCherryPickWorktreeError)
            XCTAssertEqual(worktreeError.kind, .existing)
            XCTAssertEqual(
                worktreeError.path.resolvingSymlinksInPath().path,
                worktreeURL.resolvingSymlinksInPath().path
            )
            XCTAssertTrue(error.localizedDescription.contains(worktreeError.path.path))
            XCTAssertTrue(error.localizedDescription.localizedCaseInsensitiveContains("conflict"))
            XCTAssertFalse(try runGitOutput(["rev-parse", "--verify", "CHERRY_PICK_HEAD"], in: worktreeURL).isEmpty)
        }

        XCTAssertEqual(try runGitOutput(["branch", "--show-current"], in: repoURL), "main")
        XCTAssertEqual(try runGitOutput(["rev-parse", "HEAD"], in: repoURL), mainHead)
        XCTAssertEqual(try runGitOutput(["status", "--porcelain"], in: repoURL), "")
        XCTAssertEqual(try String(contentsOf: repoURL.appendingPathComponent("tracked.txt"), encoding: .utf8), "main\n")
    }

    func testCherryPickNonConflictFailureRemovesTemporaryWorktree() async throws {
        let repoURL = try makeTempRepo()
        let mainHead = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)
        try runGit(["branch", "release"], in: repoURL)

        do {
            try await GitStatusService.shared.cherryPickCommits(
                ["not-a-commit"],
                onto: "release",
                in: repoURL
            )
            XCTFail("cherry-pick should fail")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("not-a-commit"))
        }

        XCTAssertEqual(try runGitOutput(["branch", "--show-current"], in: repoURL), "main")
        XCTAssertEqual(try runGitOutput(["rev-parse", "HEAD"], in: repoURL), mainHead)
        XCTAssertEqual(try runGitOutput(["status", "--porcelain"], in: repoURL), "")
        XCTAssertNil(try worktreePath(for: "release", in: repoURL))
    }

    func testRevertUndoResetsToOldHead() async throws {
        let repoURL = try makeTempRepo()
        try "changed\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "tracked.txt"], in: repoURL)
        try runGit(["commit", "-m", "change tracked"], in: repoURL)

        let oldHead = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)
        let executor = GitUndoExecutor()

        try await executor.execute(.revert(commit: oldHead), in: repoURL)
        let newHead = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)
        try await executor.execute(.resetHead(target: oldHead, mode: .hard, expectedHead: newHead), in: repoURL)

        XCTAssertEqual(try runGitOutput(["rev-parse", "HEAD"], in: repoURL), oldHead)
        XCTAssertEqual(try String(contentsOf: repoURL.appendingPathComponent("tracked.txt"), encoding: .utf8), "changed\n")
    }

    func testResetUndoRestoresOldHead() async throws {
        let repoURL = try makeTempRepo()
        try "second\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "tracked.txt"], in: repoURL)
        try runGit(["commit", "-m", "second"], in: repoURL)

        let oldHead = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)
        let target = try runGitOutput(["rev-parse", "HEAD~1"], in: repoURL)
        let executor = GitUndoExecutor()

        try await executor.execute(.resetHead(target: target, mode: .hard, expectedHead: oldHead), in: repoURL)
        try await executor.execute(.resetHead(target: oldHead, mode: .hard, expectedHead: target), in: repoURL)

        XCTAssertEqual(try runGitOutput(["rev-parse", "HEAD"], in: repoURL), oldHead)
        XCTAssertEqual(try String(contentsOf: repoURL.appendingPathComponent("tracked.txt"), encoding: .utf8), "second\n")
    }

    func testMergeUndoResetsToOldHead() async throws {
        let repoURL = try makeRepoWithFeatureCommit()
        let oldHead = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)
        let executor = GitUndoExecutor()

        try await executor.execute(.mergeCommit(commit: "feature", noCommit: false, log: false), in: repoURL)
        let newHead = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)
        try await executor.execute(.resetHead(target: oldHead, mode: .hard, expectedHead: newHead), in: repoURL)

        XCTAssertEqual(try runGitOutput(["rev-parse", "HEAD"], in: repoURL), oldHead)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repoURL.appendingPathComponent("feature.txt").path))
    }

    private func makeTempRepo() throws -> URL {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-undo-history-base-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        try runGit(["init", "-b", "main"], in: repoURL)
        try runGit(["config", "user.name", "Mac Git Tests"], in: repoURL)
        try runGit(["config", "user.email", "tests@example.com"], in: repoURL)
        try "base\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "tracked.txt"], in: repoURL)
        try runGit(["commit", "-m", "initial"], in: repoURL)
        return repoURL
    }

    private func makeRepoWithFeatureCommit() throws -> URL {
        let repoURL = try makeTempRepo()
        try runGit(["checkout", "-b", "feature"], in: repoURL)
        try "feature\n".write(to: repoURL.appendingPathComponent("feature.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "feature.txt"], in: repoURL)
        try runGit(["commit", "-m", "feature"], in: repoURL)
        try runGit(["checkout", "main"], in: repoURL)
        return repoURL
    }

    private func makeRepoWithTwoFeatureCommits() throws -> URL {
        let repoURL = try makeTempRepo()
        try runGit(["checkout", "-b", "feature"], in: repoURL)

        try "feature one\n".write(
            to: repoURL.appendingPathComponent("feature-one.txt"),
            atomically: true,
            encoding: .utf8
        )
        try runGit(["add", "feature-one.txt"], in: repoURL)
        try runGit(["commit", "-m", "feature one"], in: repoURL)

        try "feature two\n".write(
            to: repoURL.appendingPathComponent("feature-two.txt"),
            atomically: true,
            encoding: .utf8
        )
        try runGit(["add", "feature-two.txt"], in: repoURL)
        try runGit(["commit", "-m", "feature two"], in: repoURL)

        try runGit(["checkout", "main"], in: repoURL)
        return repoURL
    }

    private func makeRepoWithConflictingFeatureCommit() throws -> URL {
        let repoURL = try makeTempRepo()
        try runGit(["checkout", "-b", "feature"], in: repoURL)
        try "feature\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "tracked.txt"], in: repoURL)
        try runGit(["commit", "-m", "feature change"], in: repoURL)

        try runGit(["checkout", "main"], in: repoURL)
        try "main\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "tracked.txt"], in: repoURL)
        try runGit(["commit", "-m", "main change"], in: repoURL)
        return repoURL
    }

    private func worktreePath(for branch: String, in repositoryURL: URL) throws -> URL? {
        let output = try runGitOutput(["worktree", "list", "--porcelain"], in: repositoryURL)
        let branchRef = "branch refs/heads/\(branch)"

        for block in output.components(separatedBy: "\n\n") where block.contains(branchRef) {
            guard let pathLine = block.components(separatedBy: "\n").first(where: { $0.hasPrefix("worktree ") }) else {
                continue
            }
            let path = String(pathLine.dropFirst("worktree ".count))
            return URL(fileURLWithPath: path, isDirectory: true)
        }

        return nil
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
