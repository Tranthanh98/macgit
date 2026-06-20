# Git Undo Phase 2 Commits Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add undo and redo for normal commits while preserving staged changes after undo.

**Architecture:** Capture `oldHEAD` before commit and `newHEAD` after commit, then register an undo entry that runs `git reset --soft oldHEAD` only if `HEAD` still equals `newHEAD`. Redo re-runs `git commit` with the original message and options.

**Tech Stack:** Swift 6, SwiftUI, XCTest, `xcodebuild`, `git reset --soft`, `git commit`.

---

## Prerequisite

Complete and merge Phase 0 + 1A from `docs/superpowers/plans/2026-06-19-git-undo-phase-0-1a.md`. Phase 1B is not required for this phase.

## Scope

This plan supports normal commits from the toolbar and file-status commit bar. It excludes amend commits because undoing amend requires preserving both the replaced commit and the amended commit.

## File Structure

- Modify `macgit/Services/GitUndoModels.swift`: add reset, commit, and expected-HEAD operations.
- Modify `macgit/Services/GitUndoExecutor.swift`: check `HEAD` and execute reset/commit.
- Modify `macgit/Services/GitStatusService+Commit.swift`: add `headHash(in:)` helper if `tipHash(for:"HEAD")` is not used directly.
- Modify `macgit/Services/SyncState.swift`: accept optional undo manager in `performCommit`.
- Modify `macgit/Views/FileStatus/FileStatusView.swift`: register commit undo for commit-bar commits.
- Modify `macgit/Views/MainWindow/MainWindowView.swift`: pass undo manager into toolbar commit flow.
- Create `macgitTests/GitUndoCommitExecutorTests.swift`: unit tests for expected-HEAD checking and commands.
- Create `macgitTests/GitUndoCommitIntegrationTests.swift`: real-repo tests for commit undo and redo.

## Task 1: Add Commit Undo Operations to the Executor

**Files:**
- Modify: `macgit/Services/GitUndoModels.swift`
- Modify: `macgit/Services/GitUndoExecutor.swift`
- Create: `macgitTests/GitUndoCommitExecutorTests.swift`

- [ ] **Step 1: Write failing executor tests**

Create `macgitTests/GitUndoCommitExecutorTests.swift`:

```swift
import XCTest
@testable import macgit

final class GitUndoCommitExecutorTests: XCTestCase {
    func testResetSoftChecksExpectedHeadBeforeResetting() async throws {
        let runner = RecordingGitRunner(outputs: ["rev-parse HEAD": "new-head\n"])
        let executor = GitUndoExecutor(runner: runner)
        let repoURL = URL(fileURLWithPath: "/tmp/repo")

        try await executor.execute(
            .resetHead(target: "old-head", mode: .soft, expectedHead: "new-head"),
            in: repoURL
        )

        let calls = await runner.recordedArguments()
        XCTAssertEqual(calls, [
            ["rev-parse", "HEAD"],
            ["reset", "--soft", "old-head"]
        ])
    }

    func testResetSoftThrowsWhenHeadHasMoved() async throws {
        let runner = RecordingGitRunner(outputs: ["rev-parse HEAD": "someone-else\n"])
        let executor = GitUndoExecutor(runner: runner)

        do {
            try await executor.execute(
                .resetHead(target: "old-head", mode: .soft, expectedHead: "new-head"),
                in: URL(fileURLWithPath: "/tmp/repo")
            )
            XCTFail("Expected expectedHeadMismatch")
        } catch let error as GitUndoError {
            XCTAssertEqual(error, .expectedHeadMismatch(expected: "new-head", actual: "someone-else"))
        }
    }

    func testCommitOperationRunsGitCommitWithOptions() async throws {
        let runner = RecordingGitRunner(outputs: [:])
        let executor = GitUndoExecutor(runner: runner)

        try await executor.execute(
            .commit(message: "ship it", noVerify: true, signOff: true),
            in: URL(fileURLWithPath: "/tmp/repo")
        )

        let calls = await runner.recordedArguments()
        XCTAssertEqual(calls, [
            ["commit", "-m", "ship it", "--no-verify", "--signoff"]
        ])
    }
}

private actor RecordingGitRunner: GitCommandRunning {
    private let outputs: [String: String]
    private var calls: [[String]] = []

    init(outputs: [String: String]) {
        self.outputs = outputs
    }

    func runGit(arguments: [String], in directory: URL) async throws -> String {
        calls.append(arguments)
        return outputs[arguments.joined(separator: " ")] ?? ""
    }

    func recordedArguments() -> [[String]] {
        calls
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitUndoCommitExecutorTests
```

Expected: compilation fails with missing `resetHead`, `commit`, and `GitUndoResetMode`.

- [ ] **Step 3: Extend models**

In `macgit/Services/GitUndoModels.swift`, add:

```swift
enum GitUndoResetMode: Equatable {
    case soft
    case mixed
    case hard

    var flag: String {
        switch self {
        case .soft: return "--soft"
        case .mixed: return "--mixed"
        case .hard: return "--hard"
        }
    }
}
```

Update `GitUndoOperation`:

```swift
enum GitUndoOperation: Equatable {
    case stageFiles(paths: [String])
    case unstageFiles(paths: [String])
    case applyPatch(patch: String, cached: Bool, reverse: Bool)
    case resetHead(target: String, mode: GitUndoResetMode, expectedHead: String?)
    case commit(message: String, noVerify: Bool, signOff: Bool)
}
```

Update `GitUndoError` in `macgit/Services/GitUndoExecutor.swift`:

```swift
case expectedHeadMismatch(expected: String, actual: String)
```

and add the description:

```swift
case .expectedHeadMismatch(let expected, let actual):
    return "Cannot undo because HEAD moved. Expected \(expected), but found \(actual)."
```

- [ ] **Step 4: Extend executor**

In `GitUndoExecutor.execute(_:in:)`, add:

```swift
case .resetHead(let target, let mode, let expectedHead):
    if let expectedHead {
        let actual = try await runner.runGit(arguments: ["rev-parse", "HEAD"], in: repositoryURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if actual != expectedHead {
            throw GitUndoError.expectedHeadMismatch(expected: expectedHead, actual: actual)
        }
    }
    _ = try await runner.runGit(arguments: ["reset", mode.flag, target], in: repositoryURL)
case .commit(let message, let noVerify, let signOff):
    var arguments = ["commit", "-m", message]
    if noVerify { arguments.append("--no-verify") }
    if signOff { arguments.append("--signoff") }
    _ = try await runner.runGit(arguments: arguments, in: repositoryURL)
```

- [ ] **Step 5: Run executor tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitUndoCommitExecutorTests -only-testing:macgitTests/GitUndoExecutorTests
```

Expected: commit executor tests and previous executor tests pass.

- [ ] **Step 6: Commit**

Run:

```bash
git add macgit/Services/GitUndoModels.swift macgit/Services/GitUndoExecutor.swift macgitTests/GitUndoCommitExecutorTests.swift
git commit -m "feat: support commit undo operations"
```

Expected: commit succeeds.

## Task 2: Register Undo Entries for Normal Commits

**Files:**
- Modify: `macgit/Services/SyncState.swift`
- Modify: `macgit/Views/MainWindow/MainWindowView.swift`
- Modify: `macgit/Views/FileStatus/FileStatusView.swift`

- [ ] **Step 1: Update `SyncState.performCommit` signature**

In `macgit/Services/SyncState.swift`, change:

```swift
func performCommit(message: String, repositoryURL: URL) async {
```

to:

```swift
func performCommit(
    message: String,
    repositoryURL: URL,
    undoManager: GitUndoManager? = nil,
    noVerify: Bool = false,
    signOff: Bool = false
) async {
```

Inside the method, before `GitStatusService.shared.commit`, add:

```swift
let oldHead = await GitStatusService.shared.tipHash(for: "HEAD", in: repositoryURL)
```

Replace:

```swift
try await GitStatusService.shared.commit(message: message, in: repositoryURL)
```

with:

```swift
try await GitStatusService.shared.commit(
    message: message,
    in: repositoryURL,
    noVerify: noVerify,
    signOff: signOff
)
let newHead = await GitStatusService.shared.tipHash(for: "HEAD", in: repositoryURL)
if let oldHead, let newHead, oldHead != newHead {
    await MainActor.run {
        undoManager?.register(
            GitUndoEntry(
                repositoryURL: repositoryURL,
                label: "Commit",
                undoOperation: .resetHead(target: oldHead, mode: .soft, expectedHead: newHead),
                redoOperation: .commit(message: message, noVerify: noVerify, signOff: signOff)
            )
        )
    }
}
```

- [ ] **Step 2: Pass undo manager from toolbar commit flow**

In `macgit/Views/MainWindow/MainWindowView.swift`, replace:

```swift
await syncState.performCommit(message: message, repositoryURL: repositoryURL)
```

with:

```swift
await syncState.performCommit(
    message: message,
    repositoryURL: repositoryURL,
    undoManager: undoManager
)
```

- [ ] **Step 3: Register commit undo from file-status commit bar**

In `macgit/Views/FileStatus/FileStatusView.swift`, replace the private `commit(message:)` implementation with:

```swift
private func commit(message: String) async {
    let oldHead = await GitStatusService.shared.tipHash(for: "HEAD", in: repositoryURL)
    do {
        try await GitStatusService.shared.commit(
            message: message,
            in: repositoryURL,
            amend: amendLastCommit,
            noVerify: bypassHooks,
            signOff: signOffCommit
        )
        let newHead = await GitStatusService.shared.tipHash(for: "HEAD", in: repositoryURL)
        if !amendLastCommit, let oldHead, let newHead, oldHead != newHead {
            await MainActor.run {
                undoManager?.register(
                    GitUndoEntry(
                        repositoryURL: repositoryURL,
                        label: "Commit",
                        undoOperation: .resetHead(target: oldHead, mode: .soft, expectedHead: newHead),
                        redoOperation: .commit(message: message, noVerify: bypassHooks, signOff: signOffCommit)
                    )
                )
            }
        }
        await loadStatus()
        await syncState?.refresh(repositoryURL: repositoryURL)
    } catch {
        errorMessage = error.localizedDescription
        showingError = true
    }
}
```

- [ ] **Step 4: Build**

Run:

```bash
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: app builds.

- [ ] **Step 5: Commit**

Run:

```bash
git add macgit/Services/SyncState.swift macgit/Views/MainWindow/MainWindowView.swift macgit/Views/FileStatus/FileStatusView.swift
git commit -m "feat: register undo entries for normal commits"
```

Expected: commit succeeds.

## Task 3: Verify Commit Undo in Real Repositories

**Files:**
- Create: `macgitTests/GitUndoCommitIntegrationTests.swift`

- [ ] **Step 1: Write real-repo tests**

Create `macgitTests/GitUndoCommitIntegrationTests.swift`:

```swift
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
```

- [ ] **Step 2: Run commit undo tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitUndoCommitExecutorTests -only-testing:macgitTests/GitUndoCommitIntegrationTests
```

Expected: all commit undo tests pass.

- [ ] **Step 3: Run build**

Run:

```bash
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: app builds.

- [ ] **Step 4: Commit**

Run:

```bash
git add macgitTests/GitUndoCommitIntegrationTests.swift
git commit -m "test: verify commit undo in real repos"
```

Expected: commit succeeds.

## Self-Review

Spec coverage:

- Normal commit undo is covered for toolbar and file-status commit paths.
- Redo is covered by re-running commit from restored staged changes.
- Amend is explicitly out of scope and guarded by `!amendLastCommit`.

Placeholder scan:

- Every task includes concrete code and commands.

Type consistency:

- `GitUndoResetMode`, `GitUndoOperation.resetHead`, and `GitUndoOperation.commit` are defined before executor and UI usage.
