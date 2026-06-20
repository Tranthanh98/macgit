# Git Undo Phase 3A Stash Save and Drop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add undo and redo for stash save and stash drop without changing stash apply/pop behavior.

**Architecture:** Record the stash commit hash and summary immediately after save or before drop. Undo save applies the saved stash and removes the matching stash entry; undo drop restores the captured stash commit with `git stash store`.

**Tech Stack:** Swift 6, SwiftUI, XCTest, `xcodebuild`, `git stash push`, `git stash apply`, `git stash drop`, `git stash store`.

---

## Prerequisite

Complete and merge Phase 0 + 1A from `docs/superpowers/plans/2026-06-19-git-undo-phase-0-1a.md`. Phase 2 is not required.

## Scope

This phase supports:

- Stash save from `SyncState.performStash`.
- Stash drop from `MainWindowView.performStashAction`.

This phase does not support undo for stash apply or stash pop.

## File Structure

- Create `macgit/Services/GitStashUndoSupport.swift`: helper for stash hash lookup, summary lookup, matching ref lookup, and drop-by-hash.
- Modify `macgit/Services/GitUndoModels.swift`: add stash operations.
- Modify `macgit/Services/GitUndoExecutor.swift`: execute stash operations.
- Modify `macgit/Services/SyncState.swift`: register undo for stash save.
- Modify `macgit/Views/MainWindow/MainWindowView.swift`: register undo for stash drop.
- Create `macgitTests/GitStashUndoSupportTests.swift`: real-repo tests for stash ref/hash helpers.
- Create `macgitTests/GitUndoStashSaveDropTests.swift`: real-repo tests for undo save and undo drop.

## Task 1: Add Stash Lookup Support

**Files:**
- Create: `macgit/Services/GitStashUndoSupport.swift`
- Create: `macgitTests/GitStashUndoSupportTests.swift`

- [x] **Step 1: Write failing stash support tests**

Create `macgitTests/GitStashUndoSupportTests.swift`:

```swift
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
```

- [x] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitStashUndoSupportTests
```

Expected: compilation fails with `cannot find 'GitStashUndoSupport' in scope`.

- [x] **Step 3: Create stash support helper**

Create `macgit/Services/GitStashUndoSupport.swift`:

```swift
//
//  GitStashUndoSupport.swift
//  macgit
//

import Foundation

struct GitStashUndoSupport {
    private let runner: any GitCommandRunning

    init(runner: any GitCommandRunning = GitStatusService.shared) {
        self.runner = runner
    }

    func hash(for ref: String, in repositoryURL: URL) async throws -> String {
        try await runner.runGit(arguments: ["rev-parse", "\(ref)^{commit}"], in: repositoryURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func summary(for ref: String, in repositoryURL: URL) async throws -> String {
        try await runner.runGit(arguments: ["stash", "list", "--format=%gd%x1f%gs"], in: repositoryURL)
            .split(separator: "\n")
            .compactMap { line -> String? in
                let parts = line.split(separator: "\u{001f}", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2, String(parts[0]) == ref else { return nil }
                return String(parts[1])
            }
            .first ?? "Restored stash"
    }

    func ref(matchingHash hash: String, in repositoryURL: URL) async throws -> String? {
        let refs = try await runner.runGit(arguments: ["stash", "list", "--format=%gd"], in: repositoryURL)
            .split(separator: "\n")
            .map { String($0) }
        for ref in refs {
            let refHash = try await self.hash(for: ref, in: repositoryURL)
            if refHash == hash {
                return ref
            }
        }
        return nil
    }

    func dropStash(matchingHash hash: String, in repositoryURL: URL) async throws {
        guard let ref = try await ref(matchingHash: hash, in: repositoryURL) else {
            throw GitError.commandFailed("Could not find stash entry with hash \(hash).")
        }
        _ = try await runner.runGit(arguments: ["stash", "drop", ref], in: repositoryURL)
    }
}
```

- [x] **Step 4: Run stash support tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitStashUndoSupportTests
```

Expected: tests pass.

- [x] **Step 5: Commit**

Run:

```bash
git add macgit/Services/GitStashUndoSupport.swift macgitTests/GitStashUndoSupportTests.swift
git commit -m "feat: add stash undo lookup support"
```

Expected: commit succeeds.

## Task 2: Add Stash Operations to Undo Executor

**Files:**
- Modify: `macgit/Services/GitUndoModels.swift`
- Modify: `macgit/Services/GitUndoExecutor.swift`
- Create: `macgitTests/GitUndoStashSaveDropTests.swift`

- [x] **Step 1: Extend undo operation enum**

In `macgit/Services/GitUndoModels.swift`, add these cases to `GitUndoOperation`:

```swift
case stashPush(message: String, keepIndex: Bool)
case stashApply(ref: String)
case stashApplyAndDrop(hash: String)
case stashStore(commit: String, message: String)
case stashDropMatchingHash(hash: String)
```

- [x] **Step 2: Add executor stash support**

In `GitUndoExecutor`, add a stored helper:

```swift
private let stashSupport: GitStashUndoSupport
```

Update the initializer:

```swift
init(
    runner: any GitCommandRunning = GitStatusService.shared,
    patchRunner: any GitPatchApplying = GitStatusService.shared,
    stashSupport: GitStashUndoSupport = GitStashUndoSupport()
) {
    self.runner = runner
    self.patchRunner = patchRunner
    self.stashSupport = stashSupport
}
```

Add these cases to `execute(_:in:)`:

```swift
case .stashPush(let message, let keepIndex):
    var arguments = ["stash", "push"]
    if keepIndex { arguments.append("--keep-index") }
    if !message.isEmpty {
        arguments.append(contentsOf: ["-m", message])
    }
    _ = try await runner.runGit(arguments: arguments, in: repositoryURL)
case .stashApply(let ref):
    _ = try await runner.runGit(arguments: ["stash", "apply", ref], in: repositoryURL)
case .stashApplyAndDrop(let hash):
    _ = try await runner.runGit(arguments: ["stash", "apply", hash], in: repositoryURL)
    try await stashSupport.dropStash(matchingHash: hash, in: repositoryURL)
case .stashStore(let commit, let message):
    _ = try await runner.runGit(arguments: ["stash", "store", "-m", message, commit], in: repositoryURL)
case .stashDropMatchingHash(let hash):
    try await stashSupport.dropStash(matchingHash: hash, in: repositoryURL)
```

- [x] **Step 3: Write real-repo tests for undo save and undo drop**

Create `macgitTests/GitUndoStashSaveDropTests.swift`:

```swift
import XCTest
@testable import macgit

final class GitUndoStashSaveDropTests: XCTestCase {
    func testUndoStashSaveAppliesAndDropsSavedStash() async throws {
        let repoURL = try makeTempRepo()
        try "changed\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try await GitStatusService.shared.stash(options: GitStatusService.StashOptions(message: "save undo"), in: repoURL)
        let support = GitStashUndoSupport()
        let hash = try await support.hash(for: "stash@{0}", in: repoURL)
        let executor = GitUndoExecutor()

        try await executor.execute(.stashApplyAndDrop(hash: hash), in: repoURL)

        let content = try String(contentsOf: repoURL.appendingPathComponent("tracked.txt"), encoding: .utf8)
        XCTAssertEqual(content, "changed\n")
        let stashes = await GitStatusService.shared.stashes(in: repoURL)
        XCTAssertTrue(stashes.isEmpty)
    }

    func testUndoStashDropRestoresStashEntry() async throws {
        let repoURL = try makeTempRepo()
        try "changed\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try await GitStatusService.shared.stash(options: GitStatusService.StashOptions(message: "drop undo"), in: repoURL)
        let support = GitStashUndoSupport()
        let hash = try await support.hash(for: "stash@{0}", in: repoURL)
        let summary = try await support.summary(for: "stash@{0}", in: repoURL)
        try await GitStatusService.shared.dropStash(ref: "stash@{0}", in: repoURL)

        let executor = GitUndoExecutor()
        try await executor.execute(.stashStore(commit: hash, message: summary), in: repoURL)

        let stashes = await GitStatusService.shared.stashes(in: repoURL)
        XCTAssertEqual(stashes.count, 1)
        XCTAssertEqual(try await support.hash(for: "stash@{0}", in: repoURL), hash)
    }

    private func makeTempRepo() throws -> URL {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-undo-stash-save-drop-\(UUID().uuidString)", isDirectory: true)
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

- [x] **Step 4: Run stash undo tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitUndoStashSaveDropTests
```

Expected: tests pass.

- [x] **Step 5: Commit**

Run:

```bash
git add macgit/Services/GitUndoModels.swift macgit/Services/GitUndoExecutor.swift macgitTests/GitUndoStashSaveDropTests.swift
git commit -m "feat: execute stash save and drop undo operations"
```

Expected: commit succeeds.

## Task 3: Register Stash Save and Drop Undo Entries

**Files:**
- Modify: `macgit/Services/SyncState.swift`
- Modify: `macgit/Views/MainWindow/MainWindowView.swift`

- [x] **Step 1: Register undo for stash save**

In `SyncState.performStash`, change the signature:

```swift
func performStash(options: GitStatusService.StashOptions, repositoryURL: URL, undoManager: GitUndoManager? = nil) async {
```

After successful `GitStatusService.shared.stash`, add:

```swift
let support = GitStashUndoSupport()
let hash = try await support.hash(for: "stash@{0}", in: repositoryURL)
undoManager?.register(
    GitUndoEntry(
        repositoryURL: repositoryURL,
        label: "Stash changes",
        undoOperation: .stashApplyAndDrop(hash: hash),
        redoOperation: .stashPush(message: options.message, keepIndex: options.keepIndex)
    )
)
```

- [x] **Step 2: Pass undo manager to stash sheet completion**

In `MainWindowView.stashSheet`, replace:

```swift
await syncState.performStash(options: options, repositoryURL: repositoryURL)
```

with:

```swift
await syncState.performStash(options: options, repositoryURL: repositoryURL, undoManager: undoManager)
```

- [x] **Step 3: Register undo for stash drop**

In `MainWindowView.performStashAction`, inside `case .delete`, replace:

```swift
try await GitStatusService.shared.dropStash(ref: ref, in: repositoryURL)
```

with:

```swift
let support = GitStashUndoSupport()
let hash = try await support.hash(for: ref, in: repositoryURL)
let summary = try await support.summary(for: ref, in: repositoryURL)
try await GitStatusService.shared.dropStash(ref: ref, in: repositoryURL)
undoManager.register(
    GitUndoEntry(
        repositoryURL: repositoryURL,
        label: "Drop stash",
        undoOperation: .stashStore(commit: hash, message: summary),
        redoOperation: .stashDropMatchingHash(hash: hash)
    )
)
```

- [x] **Step 4: Build and run stash tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitStashUndoSupportTests -only-testing:macgitTests/GitUndoStashSaveDropTests
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: stash tests pass and app builds.

- [x] **Step 5: Commit**

Run:

```bash
git add macgit/Services/SyncState.swift macgit/Views/MainWindow/MainWindowView.swift
git commit -m "feat: record undo entries for stash save and drop"
```

Expected: commit succeeds.

## Self-Review

Spec coverage:

- Stash save undo and redo are covered.
- Stash drop undo and redo are covered.
- Stash apply/pop are excluded and have their own plan.

Placeholder scan:

- Every task has concrete file paths, code snippets, commands, and expected outcomes.

Type consistency:

- Stash operation names in `GitUndoOperation` match executor and UI registration usage.
