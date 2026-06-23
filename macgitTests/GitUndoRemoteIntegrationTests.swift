import XCTest
@testable import macgit

final class GitUndoRemoteIntegrationTests: XCTestCase {
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
        return (remoteURL, cloneURL)
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
