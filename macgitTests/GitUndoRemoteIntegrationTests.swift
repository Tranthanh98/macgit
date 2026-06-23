import XCTest
@testable import macgit

final class GitUndoRemoteIntegrationTests: XCTestCase {
    @MainActor
    func testDeleteRemoteBranchOperationRemovesPublishedBranchWhenHashMatches() async throws {
        let fixture = try makeFixtureWithFeatureBranch()
        let support = GitRemoteUndoSupport()
        let hashOptional = try await support.remoteHash(remote: "origin", branch: "feature", in: fixture.cloneURL)
        let hash = try XCTUnwrap(hashOptional)
        let executor = GitUndoExecutor()

        try await executor.execute(.deleteRemoteBranch(remote: "origin", branch: "feature", expectedHash: hash), in: fixture.cloneURL)

        let after = try await support.remoteHash(remote: "origin", branch: "feature", in: fixture.cloneURL)
        XCTAssertNil(after)
    }

    @MainActor
    func testPullUndoAndRedoRoundTrip() async throws {
        let fixture = try makePullFixture()
        let syncState = SyncState()
        let undoManager = GitUndoManager()
        let executor = GitUndoExecutor()

        let oldHead = try await gitRevParse("HEAD", in: fixture.cloneURL)
        await syncState.performPullBranch(branch: "main", repositoryURL: fixture.cloneURL, undoManager: undoManager)
        let newHead = try await gitRevParse("HEAD", in: fixture.cloneURL)

        XCTAssertNotEqual(oldHead, newHead)
        XCTAssertEqual(undoManager.undoStack.last?.label, "Pull")

        guard let entry = undoManager.popForUndo() else {
            XCTFail("Expected an undo entry")
            return
        }
        try await executor.execute(entry.undoOperation, in: fixture.cloneURL)
        let afterUndo = try await gitRevParse("HEAD", in: fixture.cloneURL)
        XCTAssertEqual(afterUndo, oldHead)

        undoManager.completeUndo(entry)
        guard let redoEntry = undoManager.popForRedo() else {
            XCTFail("Expected a redo entry")
            return
        }
        try await executor.execute(redoEntry.redoOperation, in: fixture.cloneURL)
        let afterRedo = try await gitRevParse("HEAD", in: fixture.cloneURL)
        XCTAssertEqual(afterRedo, newHead)
    }

    @MainActor
    func testPublishUndoAndRedoRoundTrip() async throws {
        let fixture = try makePublishFixture()
        let syncState = SyncState()
        let undoManager = GitUndoManager()
        let executor = GitUndoExecutor()

        await syncState.performPush(
            options: GitStatusService.PushOptions(remote: "origin", branches: ["feature"]),
            repositoryURL: fixture.sourceURL,
            undoManager: undoManager
        )

        let support = GitRemoteUndoSupport()
        let publishedHash = try await support.remoteHash(remote: "origin", branch: "feature", in: fixture.sourceURL)
        XCTAssertNotNil(publishedHash)
        XCTAssertEqual(undoManager.undoStack.last?.label, "Publish origin/feature")

        guard let entry = undoManager.popForUndo() else {
            XCTFail("Expected an undo entry")
            return
        }
        try await executor.execute(entry.undoOperation, in: fixture.sourceURL)
        let afterUndo = try await support.remoteHash(remote: "origin", branch: "feature", in: fixture.sourceURL)
        XCTAssertNil(afterUndo)

        undoManager.completeUndo(entry)
        guard let redoEntry = undoManager.popForRedo() else {
            XCTFail("Expected a redo entry")
            return
        }
        try await executor.execute(redoEntry.redoOperation, in: fixture.sourceURL)
        let afterRedo = try await support.remoteHash(remote: "origin", branch: "feature", in: fixture.sourceURL)
        XCTAssertEqual(afterRedo, publishedHash)
    }

    private func makePullFixture() throws -> (sourceURL: URL, remoteURL: URL, cloneURL: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-pull-undo-\(UUID().uuidString)", isDirectory: true)
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
        try runGit(["init", "--bare", remoteURL.path], in: root)
        try runGit(["remote", "add", "origin", remoteURL.path], in: sourceURL)
        try runGit(["push", "-u", "origin", "main"], in: sourceURL)
        try runGit(["clone", remoteURL.path, cloneURL.path], in: root)
        try "pulled\n".write(to: sourceURL.appendingPathComponent("pulled.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "pulled.txt"], in: sourceURL)
        try runGit(["commit", "-m", "pulled"], in: sourceURL)
        try runGit(["push", "origin", "main"], in: sourceURL)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (sourceURL, remoteURL, cloneURL)
    }

    private func makePublishFixture() throws -> (sourceURL: URL, remoteURL: URL, cloneURL: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-publish-undo-\(UUID().uuidString)", isDirectory: true)
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
        try runGit(["init", "--bare", remoteURL.path], in: root)
        try runGit(["remote", "add", "origin", remoteURL.path], in: sourceURL)
        try runGit(["push", "-u", "origin", "main"], in: sourceURL)
        try runGit(["checkout", "-b", "feature"], in: sourceURL)
        try "feature\n".write(to: sourceURL.appendingPathComponent("feature.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "feature.txt"], in: sourceURL)
        try runGit(["commit", "-m", "feature"], in: sourceURL)
        try runGit(["clone", remoteURL.path, cloneURL.path], in: root)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (sourceURL, remoteURL, cloneURL)
    }

    private func makeFixtureWithFeatureBranch() throws -> (remoteURL: URL, cloneURL: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-remote-undo-integration-\(UUID().uuidString)", isDirectory: true)
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
        try runGit(["init", "--bare", remoteURL.path], in: root)
        try runGit(["remote", "add", "origin", remoteURL.path], in: sourceURL)
        try runGit(["push", "-u", "origin", "main"], in: sourceURL)
        try runGit(["checkout", "-b", "feature"], in: sourceURL)
        try "feature\n".write(to: sourceURL.appendingPathComponent("feature.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "feature.txt"], in: sourceURL)
        try runGit(["commit", "-m", "feature"], in: sourceURL)
        try runGit(["push", "origin", "feature"], in: sourceURL)
        try runGit(["clone", remoteURL.path, cloneURL.path], in: root)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (remoteURL, cloneURL)
    }

    private func gitRevParse(_ ref: String, in directory: URL) async throws -> String {
        let output = try await GitStatusService.shared.runGit(arguments: ["rev-parse", ref], in: directory)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runGit(_ arguments: [String], in directory: URL) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = arguments
        task.currentDirectoryURL = directory
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
