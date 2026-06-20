# Git Undo Phase 3B Stash Apply and Pop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add undo and redo for clean stash apply and stash pop actions.

**Architecture:** Only register undo for stash apply/pop when the working tree is clean before the action and the stash has no untracked-file payload. Undo resets the working tree back to `HEAD`; pop undo also restores the popped stash commit with `git stash store`.

**Tech Stack:** Swift 6, SwiftUI, XCTest, `xcodebuild`, `git status --porcelain`, `git stash apply`, `git stash pop`, `git reset --hard`, `git stash store`.

---

## Prerequisite

Complete and merge Phase 3A from `docs/superpowers/plans/2026-06-19-git-undo-phase-3a-stash-save-drop.md`.

## Scope

This phase supports undo for stash apply and pop only when these conditions are true before the action:

- `git status --porcelain --untracked-files=all` returns empty.
- `git stash show --only-untracked --name-only <ref>` returns empty.
- The action completes without conflicts.

If any condition fails, macgit performs the apply/pop action without registering an undo entry and shows an informational message.

## File Structure

- Modify `macgit/Services/GitStashUndoSupport.swift`: add clean-worktree and stash-untracked checks.
- Modify `macgit/Services/GitUndoModels.swift`: mark `GitUndoOperation` as `indirect` and add sequence/reset-hard operations.
- Modify `macgit/Services/GitUndoExecutor.swift`: execute sequences and reset hard.
- Modify `macgit/Views/MainWindow/MainWindowView.swift`: register undo entries for apply and pop.
- Create `macgitTests/GitUndoStashApplyPopTests.swift`: real-repo tests for clean apply/pop undo.

## Task 1: Add Safety Checks

**Files:**
- Modify: `macgit/Services/GitStashUndoSupport.swift`
- Create: `macgitTests/GitUndoStashApplyPopTests.swift`

- [x] **Step 1: Add failing safety tests**

Create `macgitTests/GitUndoStashApplyPopTests.swift`:

```swift
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
}
```

- [x] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitUndoStashApplyPopTests
```

Expected: compilation fails with `value of type 'GitStashUndoSupport' has no member 'isWorkingTreeClean'`.

- [x] **Step 3: Add safety helpers**

In `macgit/Services/GitStashUndoSupport.swift`, add:

```swift
func isWorkingTreeClean(in repositoryURL: URL) async throws -> Bool {
    let output = try await runner.runGit(
        arguments: ["status", "--porcelain", "--untracked-files=all"],
        in: repositoryURL
    )
    return output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

func stashHasUntrackedPayload(ref: String, in repositoryURL: URL) async throws -> Bool {
    let output = try await runner.runGit(
        arguments: ["stash", "show", "--only-untracked", "--name-only", ref],
        in: repositoryURL
    )
    return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}
```

- [x] **Step 4: Run safety tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitUndoStashApplyPopTests
```

Expected: current safety tests pass.

- [x] **Step 5: Commit**

Run:

```bash
git add macgit/Services/GitStashUndoSupport.swift macgitTests/GitUndoStashApplyPopTests.swift
git commit -m "feat: add stash apply undo safety checks"
```

Expected: commit succeeds.

## Task 2: Add Sequence and Reset-Hard Operations

**Files:**
- Modify: `macgit/Services/GitUndoModels.swift`
- Modify: `macgit/Services/GitUndoExecutor.swift`
- Modify: `macgitTests/GitUndoStashApplyPopTests.swift`

- [x] **Step 1: Extend models**

In `macgit/Services/GitUndoModels.swift`, change:

```swift
enum GitUndoOperation: Equatable {
```

to:

```swift
indirect enum GitUndoOperation: Equatable {
```

Add cases:

```swift
case sequence([GitUndoOperation])
case resetHardToHead(expectedHead: String?)
case stashPop(ref: String)
```

- [x] **Step 2: Extend executor**

In `GitUndoExecutor.execute(_:in:)`, add:

```swift
case .sequence(let operations):
    for operation in operations {
        try await execute(operation, in: repositoryURL)
    }
case .resetHardToHead(let expectedHead):
    if let expectedHead {
        let actual = try await runner.runGit(arguments: ["rev-parse", "HEAD"], in: repositoryURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if actual != expectedHead {
            throw GitUndoError.expectedHeadMismatch(expected: expectedHead, actual: actual)
        }
    }
    _ = try await runner.runGit(arguments: ["reset", "--hard", "HEAD"], in: repositoryURL)
case .stashPop(let ref):
    _ = try await runner.runGit(arguments: ["stash", "pop", ref], in: repositoryURL)
```

- [x] **Step 3: Append real apply/pop undo tests**

Append these tests to `GitUndoStashApplyPopTests`:

```swift
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
    XCTAssertEqual((await GitStatusService.shared.stashes(in: repoURL)).count, 1)
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
    XCTAssertEqual((await GitStatusService.shared.stashes(in: repoURL)).count, 1)
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
```

- [x] **Step 4: Run stash apply/pop tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitUndoStashApplyPopTests
```

Expected: tests pass.

- [x] **Step 5: Commit**

Run:

```bash
git add macgit/Services/GitUndoModels.swift macgit/Services/GitUndoExecutor.swift macgitTests/GitUndoStashApplyPopTests.swift
git commit -m "feat: execute stash apply and pop undo operations"
```

Expected: commit succeeds.

## Task 3: Register Stash Apply and Pop Undo Entries

**Files:**
- Modify: `macgit/Views/MainWindow/MainWindowView.swift`

- [x] **Step 1: Add a safe-registration helper**

In `MainWindowView`, add:

```swift
private func canRegisterStashApplyUndo(ref: String) async -> Bool {
    let support = GitStashUndoSupport()
    do {
        let clean = try await support.isWorkingTreeClean(in: repositoryURL)
        let hasUntrackedPayload = try await support.stashHasUntrackedPayload(ref: ref, in: repositoryURL)
        if !clean || hasUntrackedPayload {
            await MainActor.run {
                syncState.showInfo("Stash action completed without undo because the working tree or stash payload is not clean enough for a safe reset.")
            }
            return false
        }
        return true
    } catch {
        await MainActor.run {
            syncState.showError(error.localizedDescription)
        }
        return false
    }
}
```

- [x] **Step 2: Register apply undo**

In `performStashAction`, inside `case .apply`, before calling `GitStatusService.shared.applyStash`, add:

```swift
let support = GitStashUndoSupport()
let canUndo = await canRegisterStashApplyUndo(ref: ref)
let head = await GitStatusService.shared.tipHash(for: "HEAD", in: repositoryURL)
let hash = try await support.hash(for: ref, in: repositoryURL)
let summary = try await support.summary(for: ref, in: repositoryURL)
```

After successful apply, add:

```swift
if canUndo, let head {
    let undoOperation: GitUndoOperation
    if deleteAfterApplying {
        undoOperation = .sequence([
            .resetHardToHead(expectedHead: head),
            .stashStore(commit: hash, message: summary)
        ])
    } else {
        undoOperation = .resetHardToHead(expectedHead: head)
    }
    undoManager.register(
        GitUndoEntry(
            repositoryURL: repositoryURL,
            label: deleteAfterApplying ? "Pop stash" : "Apply stash",
            undoOperation: undoOperation,
            redoOperation: deleteAfterApplying ? .stashPop(ref: ref) : .stashApply(ref: hash)
        )
    )
}
```

- [x] **Step 3: Build and run tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitUndoStashApplyPopTests
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: tests pass and app builds.

- [x] **Step 4: Commit**

Run:

```bash
git add macgit/Views/MainWindow/MainWindowView.swift
git commit -m "feat: record undo entries for safe stash apply"
```

Expected: commit succeeds.

## Self-Review

Spec coverage:

- Clean stash apply and pop are undoable.
- Dirty worktree and untracked stash payload cases do not register unsafe undo entries.

Placeholder scan:

- All safety checks, operations, and commands are explicit.

Type consistency:

- `GitUndoOperation.sequence`, `resetHardToHead`, and `stashPop` are defined before UI registration uses them.
