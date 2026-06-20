import XCTest
@testable import macgit

final class GitUndoStashApplyPopTests: XCTestCase {
    func testCleanWorktreeCheckReturnsTrueForCleanRepo() async throws {
        let repoURL = try makeTempRepo()
        let support = GitStashUndoSupport()

        let isClean = try await support.isWorkingTreeClean(in: repoURL)

        XCTAssertTrue(isClean)
    }

    func testCleanWorktreeCheckReturnsFalseForDirtyRepo() async throws {
        let repoURL = try makeTempRepo()
        try "dirty\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        let support = GitStashUndoSupport()

        let isClean = try await support.isWorkingTreeClean(in: repoURL)

        XCTAssertFalse(isClean)
    }

    func testStashHasUntrackedPayloadReturnsFalseForTrackedOnlyStash() async throws {
        let repoURL = try makeTempRepo()
        try "stashed\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try runGit(["stash", "push", "-m", "tracked only"], in: repoURL)
        let support = GitStashUndoSupport()

        let hasPayload = try await support.stashHasUntrackedPayload(ref: "stash@{0}", in: repoURL)

        XCTAssertFalse(hasPayload)
    }

    func testStashHasUntrackedPayloadReturnsTrueForUntrackedStash() async throws {
        let repoURL = try makeTempRepo()
        FileManager.default.createFile(
            atPath: repoURL.appendingPathComponent("untracked.txt").path,
            contents: Data("new file\n".utf8),
            attributes: nil
        )
        let support = GitStashUndoSupport()
        try runGit(["stash", "push", "-u", "-m", "untracked stash"], in: repoURL)

        let hasPayload = try await support.stashHasUntrackedPayload(ref: "stash@{0}", in: repoURL)

        XCTAssertTrue(hasPayload)
    }

    func testUndoStashApplyFromCleanRepoResetsAppliedChanges() async throws {
        let repoURL = try makeTempRepo()
        try "stashed\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try runGit(["stash", "push", "-m", "apply me"], in: repoURL)
        let support = GitStashUndoSupport()
        let head = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)
        let hash = try await support.hash(for: "stash@{0}", in: repoURL)
        let executor = GitUndoExecutor()

        try await executor.execute(.stashApply(ref: hash), in: repoURL)
        try await executor.execute(.resetHardToHead(expectedHead: head), in: repoURL)

        let content = try String(contentsOf: repoURL.appendingPathComponent("tracked.txt"), encoding: .utf8)
        XCTAssertEqual(content, "base\n")
        let stashes = await GitStatusService.shared.stashes(in: repoURL)
        XCTAssertEqual(stashes.count, 1)
    }

    func testUndoStashPopFromCleanRepoResetsChangesAndRestoresStash() async throws {
        let repoURL = try makeTempRepo()
        try "stashed\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try runGit(["stash", "push", "-m", "pop me"], in: repoURL)
        let support = GitStashUndoSupport()
        let head = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)
        let hash = try await support.hash(for: "stash@{0}", in: repoURL)
        let summary = try await support.summary(for: "stash@{0}", in: repoURL)
        let executor = GitUndoExecutor()

        try await executor.execute(.stashPop(ref: "stash@{0}"), in: repoURL)
        try await executor.execute(
            .sequence([
                .resetHardToHead(expectedHead: head),
                .stashStore(commit: hash, message: summary)
            ]),
            in: repoURL
        )

        let content = try String(contentsOf: repoURL.appendingPathComponent("tracked.txt"), encoding: .utf8)
        XCTAssertEqual(content, "base\n")
        let stashes = await GitStatusService.shared.stashes(in: repoURL)
        XCTAssertEqual(stashes.count, 1)
    }

    private func makeTempRepo() throws -> URL {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-undo-stash-apply-pop-\(UUID().uuidString)", isDirectory: true)
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
