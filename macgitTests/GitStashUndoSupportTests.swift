import XCTest
@testable import macgit

final class GitStashUndoSupportTests: XCTestCase {
    func testStashHashSummaryAndMatchingRefCanBeResolved() async throws {
        let repoURL = try makeTempRepoWithOneStash(message: "save me")
        let support = GitStashUndoSupport()

        let hash = try await support.hash(for: "stash@{0}", in: repoURL)
        let summary = try await support.summary(for: "stash@{0}", in: repoURL)
        let matchingRef = try await support.ref(matchingHash: hash, in: repoURL)

        XCTAssertFalse(hash.isEmpty)
        XCTAssertTrue(summary.contains("save me"))
        XCTAssertEqual(matchingRef, "stash@{0}")
    }

    private func makeTempRepoWithOneStash(message: String) throws -> URL {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-stash-undo-support-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        try runGit(["init", "-b", "main"], in: repoURL)
        try runGit(["config", "user.name", "Mac Git Tests"], in: repoURL)
        try runGit(["config", "user.email", "tests@example.com"], in: repoURL)
        try "base\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "tracked.txt"], in: repoURL)
        try runGit(["commit", "-m", "initial"], in: repoURL)
        try "changed\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try runGit(["stash", "push", "-m", message], in: repoURL)
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
