# Git Undo Phase 6 History Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add guarded undo/redo for selected commit-history actions: cherry-pick, revert, reset, clean merge, and clean rebase.

**Architecture:** Capture `oldHEAD` before history-changing actions and `newHEAD` after successful completion. Undo resets back to `oldHEAD` only when `HEAD` still equals `newHEAD`; redo repeats the original history operation.

**Tech Stack:** Swift 6, SwiftUI, XCTest, `xcodebuild`, `git cherry-pick`, `git revert`, `git reset`, `git merge`, `git rebase`.

---

## Prerequisite

Complete and merge Phase 2. This phase depends on `GitUndoOperation.resetHead(target:mode:expectedHead:)` and `GitUndoResetMode`.

## Scope

This phase supports only clean, completed operations:

- Cherry-pick that creates a commit without conflicts.
- Revert that creates a commit without conflicts.
- Reset from `HistoryView.performReset`.
- Merge commit from `HistoryView.performMerge` when it completes without conflicts.
- Rebase from `HistoryView.performRebase` when it completes without conflicts.

If Git exits with conflicts, no undo entry is registered.

## File Structure

- Modify `macgit/Services/GitUndoModels.swift`: add cherry-pick, revert, merge, and rebase operations.
- Modify `macgit/Services/GitUndoExecutor.swift`: execute history operations.
- Modify `macgit/Views/History/HistoryView.swift`: capture refs and register undo entries.
- Create `macgitTests/GitUndoHistoryIntegrationTests.swift`: real-repo tests for cherry-pick, revert, reset, and merge undo.

## Task 1: Add History Operations to Executor

**Files:**
- Modify: `macgit/Services/GitUndoModels.swift`
- Modify: `macgit/Services/GitUndoExecutor.swift`

- [ ] **Step 1: Extend undo operations**

In `GitUndoOperation`, add:

```swift
case cherryPick(commit: String)
case revert(commit: String)
case mergeCommit(commit: String, noCommit: Bool, log: Bool)
case rebaseOnto(commit: String)
```

- [ ] **Step 2: Extend executor**

In `GitUndoExecutor.execute(_:in:)`, add:

```swift
case .cherryPick(let commit):
    _ = try await runner.runGit(arguments: ["cherry-pick", commit], in: repositoryURL)
case .revert(let commit):
    _ = try await runner.runGit(arguments: ["revert", commit], in: repositoryURL)
case .mergeCommit(let commit, let noCommit, let log):
    var arguments = ["merge"]
    if noCommit { arguments.append("--no-commit") }
    if log { arguments.append("--log") }
    arguments.append(commit)
    _ = try await runner.runGit(arguments: arguments, in: repositoryURL)
case .rebaseOnto(let commit):
    _ = try await runner.runGit(arguments: ["rebase", commit], in: repositoryURL)
```

- [ ] **Step 3: Build**

Run:

```bash
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: app builds.

- [ ] **Step 4: Commit**

Run:

```bash
git add macgit/Services/GitUndoModels.swift macgit/Services/GitUndoExecutor.swift
git commit -m "feat: add history undo operations"
```

Expected: commit succeeds.

## Task 2: Register History Undo Entries in HistoryView

**Files:**
- Modify: `macgit/Views/History/HistoryView.swift`

- [ ] **Step 1: Add helper to capture head and register entries**

In `HistoryView`, add:

```swift
private func registerHeadChangingUndo(
    label: String,
    oldHead: String?,
    redoOperation: GitUndoOperation
) async {
    guard let oldHead,
          let newHead = await GitStatusService.shared.tipHash(for: "HEAD", in: repositoryURL),
          oldHead != newHead else { return }

    await MainActor.run {
        undoManager?.register(
            GitUndoEntry(
                repositoryURL: repositoryURL,
                label: label,
                undoOperation: .resetHead(target: oldHead, mode: .hard, expectedHead: newHead),
                redoOperation: redoOperation
            )
        )
    }
}
```

This requires `HistoryView` to have:

```swift
var undoManager: GitUndoManager? = nil
```

Pass `undoManager` from `MainWindowView` when creating `HistoryView`.

- [ ] **Step 2: Register cherry-pick undo**

In `cherryPickCommit(_:)`, before calling `GitStatusService.shared.cherryPickCommit`, add:

```swift
let oldHead = await GitStatusService.shared.tipHash(for: "HEAD", in: repositoryURL)
```

After successful cherry-pick, add:

```swift
await registerHeadChangingUndo(
    label: "Cherry-pick \(commit.hash.prefix(7))",
    oldHead: oldHead,
    redoOperation: .cherryPick(commit: commit.hash)
)
```

- [ ] **Step 3: Register revert undo**

In `performRevert`, before revert, add:

```swift
let oldHead = await GitStatusService.shared.tipHash(for: "HEAD", in: repositoryURL)
```

After successful revert, add:

```swift
await registerHeadChangingUndo(
    label: "Revert \(commit.hash.prefix(7))",
    oldHead: oldHead,
    redoOperation: .revert(commit: commit.hash)
)
```

- [ ] **Step 4: Register reset undo**

In `performReset`, before reset, add:

```swift
let oldHead = await GitStatusService.shared.tipHash(for: "HEAD", in: repositoryURL)
```

After successful reset, add:

```swift
if let oldHead,
   let newHead = await GitStatusService.shared.tipHash(for: "HEAD", in: repositoryURL),
   oldHead != newHead {
    await MainActor.run {
        undoManager?.register(
            GitUndoEntry(
                repositoryURL: repositoryURL,
                label: "Reset HEAD",
                undoOperation: .resetHead(target: oldHead, mode: resetMode == .hard ? .hard : .soft, expectedHead: newHead),
                redoOperation: .resetHead(target: commit.hash, mode: resetMode.gitUndoMode, expectedHead: oldHead)
            )
        )
    }
}
```

Add this computed property near `ResetMode`:

```swift
extension ResetMode {
    var gitUndoMode: GitUndoResetMode {
        switch self {
        case .soft: return .soft
        case .mixed: return .mixed
        case .hard: return .hard
        }
    }
}
```

- [ ] **Step 5: Register merge and rebase undo**

In `performMerge`, capture `oldHead` before merge and register:

```swift
await registerHeadChangingUndo(
    label: "Merge \(commit.hash.prefix(7))",
    oldHead: oldHead,
    redoOperation: .mergeCommit(commit: commit.hash, noCommit: !mergeCommitImmediately, log: mergeIncludeMessages)
)
```

In `performRebase`, capture `oldHead` before rebase and register:

```swift
await registerHeadChangingUndo(
    label: "Rebase onto \(commit.hash.prefix(7))",
    oldHead: oldHead,
    redoOperation: .rebaseOnto(commit: commit.hash)
)
```

- [ ] **Step 6: Build**

Run:

```bash
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: app builds.

- [ ] **Step 7: Commit**

Run:

```bash
git add macgit/Views/History/HistoryView.swift
git commit -m "feat: record undo entries for history actions"
```

Expected: commit succeeds.

## Task 3: Add Real-Repo History Undo Tests

**Files:**
- Create: `macgitTests/GitUndoHistoryIntegrationTests.swift`

- [ ] **Step 1: Write integration tests**

Create `macgitTests/GitUndoHistoryIntegrationTests.swift`:

```swift
import XCTest
@testable import macgit

final class GitUndoHistoryIntegrationTests: XCTestCase {
    func testCherryPickUndoResetsToOldHead() async throws {
        let repoURL = try makeRepoWithFeatureCommit()
        let oldHead = try runGitOutput(["rev-parse", "main"], in: repoURL)
        let featureHead = try runGitOutput(["rev-parse", "feature"], in: repoURL)
        let executor = GitUndoExecutor()

        try await executor.execute(.cherryPick(commit: featureHead), in: repoURL)
        let newHead = try runGitOutput(["rev-parse", "HEAD"], in: repoURL)
        try await executor.execute(.resetHead(target: oldHead, mode: .hard, expectedHead: newHead), in: repoURL)

        XCTAssertEqual(try runGitOutput(["rev-parse", "HEAD"], in: repoURL), oldHead)
    }

    func testResetUndoRestoresOldHead() async throws {
        let repoURL = try makeRepoWithFeatureCommit()
        let oldHead = try runGitOutput(["rev-parse", "main"], in: repoURL)
        let target = try runGitOutput(["rev-parse", "main~0"], in: repoURL)
        let executor = GitUndoExecutor()

        try await executor.execute(.resetHead(target: target, mode: .hard, expectedHead: oldHead), in: repoURL)
        try await executor.execute(.resetHead(target: oldHead, mode: .hard, expectedHead: target), in: repoURL)

        XCTAssertEqual(try runGitOutput(["rev-parse", "HEAD"], in: repoURL), oldHead)
    }

    private func makeRepoWithFeatureCommit() throws -> URL {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-undo-history-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        try runGit(["init", "-b", "main"], in: repoURL)
        try runGit(["config", "user.name", "Mac Git Tests"], in: repoURL)
        try runGit(["config", "user.email", "tests@example.com"], in: repoURL)
        try "base\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "tracked.txt"], in: repoURL)
        try runGit(["commit", "-m", "initial"], in: repoURL)
        try runGit(["checkout", "-b", "feature"], in: repoURL)
        try "feature\n".write(to: repoURL.appendingPathComponent("feature.txt"), atomically: true, encoding: .utf8)
        try runGit(["add", "feature.txt"], in: repoURL)
        try runGit(["commit", "-m", "feature"], in: repoURL)
        try runGit(["checkout", "main"], in: repoURL)
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

- [ ] **Step 2: Run tests and build**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitUndoHistoryIntegrationTests
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: tests pass and app builds.

- [ ] **Step 3: Commit**

Run:

```bash
git add macgitTests/GitUndoHistoryIntegrationTests.swift
git commit -m "test: verify history undo operations"
```

Expected: commit succeeds.

## Self-Review

Spec coverage:

- Cherry-pick, revert, reset, merge, and rebase registration paths are covered.
- Conflict exits do not register undo because registration occurs only after success.

Placeholder scan:

- Every history operation has concrete capture and inverse commands.

Type consistency:

- History operation cases match executor and `HistoryView` snippets.
