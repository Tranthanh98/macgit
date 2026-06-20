# Git Undo Phase 7 Remote Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add explicit-confirmation undo for the safest remote actions: pull merge/rebase rollback and newly published branch removal.

**Architecture:** Remote undo entries carry a confirmation message and are never executed silently from Cmd+Z. Pull undo resets local `HEAD` back to the captured pre-pull hash; publish undo deletes the newly created remote branch only when the remote ref still points to the pushed hash.

**Tech Stack:** Swift 6, SwiftUI confirmation dialogs, XCTest, `xcodebuild`, `git ls-remote`, `git push --delete`, `git reset`.

---

## Prerequisite

Complete and merge Phase 2 and Phase 4. This phase needs reset operations, branch naming support, and the ability to add metadata to undo entries.

## Scope

This phase supports:

- Pull undo for successful pull operations that moved `HEAD`.
- Publish-new-branch undo for push operations that created a remote branch.

This phase does not undo ordinary pushes to an existing remote branch. Rewriting existing remote history should be a separate explicitly named action, not a generic Undo menu command.

## File Structure

- Modify `macgit/Services/GitUndoModels.swift`: add optional `confirmationMessage` to `GitUndoEntry` and remote operations.
- Modify `macgit/Services/GitUndoExecutor.swift`: execute remote delete with expected hash check.
- Create `macgit/Services/GitRemoteUndoSupport.swift`: remote ref hash lookup and branch existence helpers.
- Modify `macgit/Services/SyncState.swift`: register pull and publish undo entries.
- Modify `macgit/Views/MainWindow/MainWindowView.swift`: show confirmation before executing undo entries that require confirmation.
- Create `macgitTests/GitRemoteUndoSupportTests.swift`: local bare-remote tests.
- Create `macgitTests/GitUndoRemoteIntegrationTests.swift`: pull/publish undo tests using local bare repositories.

## Task 1: Add Confirmation Metadata to Undo Entries

**Files:**
- Modify: `macgit/Services/GitUndoModels.swift`
- Modify: `macgit/Views/MainWindow/MainWindowView.swift`

- [ ] **Step 1: Extend `GitUndoEntry`**

In `GitUndoEntry`, add a stored property:

```swift
let confirmationMessage: String?
```

Update the initializer signature:

```swift
confirmationMessage: String? = nil
```

Assign it:

```swift
self.confirmationMessage = confirmationMessage
```

Existing call sites continue compiling because the new parameter has a default value.

- [ ] **Step 2: Add pending remote undo state**

In `MainWindowView`, add:

```swift
@State private var pendingConfirmedUndo: (entry: GitUndoEntry, action: GitUndoMenuAction)?
```

Add this confirmation dialog to the view modifier chain:

```swift
.confirmationDialog(
    "Confirm Git Undo",
    isPresented: Binding(
        get: { pendingConfirmedUndo != nil },
        set: { isPresented in
            if !isPresented { pendingConfirmedUndo = nil }
        }
    ),
    titleVisibility: .visible
) {
    Button("Undo", role: .destructive) {
        if let pending = pendingConfirmedUndo {
            let entry = pending.entry
            let action = pending.action
            pendingConfirmedUndo = nil
            Task {
                await executeUndoEntry(entry, menuAction: action)
            }
        }
    }
    Button("Cancel", role: .cancel) {
        if let pending = pendingConfirmedUndo {
            switch pending.action {
            case .undo:
                undoManager.restoreUndo(pending.entry)
            case .redo:
                undoManager.restoreRedo(pending.entry)
            }
        }
        pendingConfirmedUndo = nil
    }
} message: {
    Text(pendingConfirmedUndo?.entry.confirmationMessage ?? "")
}
```

- [ ] **Step 3: Route confirmed entries before execution**

In `handleGitUndoMenuAction(_:)`, after popping an entry and before starting `Task`, add:

```swift
if entry.confirmationMessage != nil {
    pendingConfirmedUndo = (entry, action)
    return
}
```

Use this for both undo and redo branches.

- [ ] **Step 4: Build**

Run:

```bash
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: app builds.

- [ ] **Step 5: Commit**

Run:

```bash
git add macgit/Services/GitUndoModels.swift macgit/Views/MainWindow/MainWindowView.swift
git commit -m "feat: require confirmation for remote undo entries"
```

Expected: commit succeeds.

## Task 2: Add Remote Ref Support and Operations

**Files:**
- Create: `macgit/Services/GitRemoteUndoSupport.swift`
- Modify: `macgit/Services/GitUndoModels.swift`
- Modify: `macgit/Services/GitUndoExecutor.swift`
- Create: `macgitTests/GitRemoteUndoSupportTests.swift`

- [ ] **Step 1: Write failing remote support tests**

Create `macgitTests/GitRemoteUndoSupportTests.swift`:

```swift
import XCTest
@testable import macgit

final class GitRemoteUndoSupportTests: XCTestCase {
    func testRemoteBranchHashCanBeReadFromBareRemote() async throws {
        let fixture = try makeLocalRemoteFixture()
        let support = GitRemoteUndoSupport()

        let hash = try await support.remoteHash(remote: "origin", branch: "main", in: fixture.cloneURL)

        XCTAssertEqual(hash, fixture.mainHash)
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
```

- [ ] **Step 2: Create remote support**

Create `macgit/Services/GitRemoteUndoSupport.swift`:

```swift
//
//  GitRemoteUndoSupport.swift
//  macgit
//

import Foundation

struct GitRemoteUndoSupport {
    private let runner: any GitCommandRunning

    init(runner: any GitCommandRunning = GitStatusService.shared) {
        self.runner = runner
    }

    func remoteHash(remote: String, branch: String, in repositoryURL: URL) async throws -> String? {
        let output = try await runner.runGit(arguments: ["ls-remote", remote, "refs/heads/\(branch)"], in: repositoryURL)
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.split(separator: "\t").first.map(String.init)
    }
}
```

- [ ] **Step 3: Add remote operation cases**

In `GitUndoOperation`, add:

```swift
case deleteRemoteBranch(remote: String, branch: String, expectedHash: String)
```

In `GitUndoExecutor`, add:

```swift
private let remoteSupport: GitRemoteUndoSupport
```

Update initializer with:

```swift
remoteSupport: GitRemoteUndoSupport = GitRemoteUndoSupport()
```

and assign it:

```swift
self.remoteSupport = remoteSupport
```

Add executor case:

```swift
case .deleteRemoteBranch(let remote, let branch, let expectedHash):
    let actualHash = try await remoteSupport.remoteHash(remote: remote, branch: branch, in: repositoryURL)
    guard actualHash == expectedHash else {
        throw GitError.commandFailed("Cannot delete remote branch '\(branch)' because its remote hash changed.")
    }
    _ = try await runner.runGit(arguments: ["push", remote, "--delete", branch], in: repositoryURL)
```

- [ ] **Step 4: Run tests and build**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitRemoteUndoSupportTests
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: tests pass and app builds.

- [ ] **Step 5: Commit**

Run:

```bash
git add macgit/Services/GitRemoteUndoSupport.swift macgit/Services/GitUndoModels.swift macgit/Services/GitUndoExecutor.swift macgitTests/GitRemoteUndoSupportTests.swift
git commit -m "feat: add remote branch undo operations"
```

Expected: commit succeeds.

## Task 3: Register Pull and Publish Undo Entries

**Files:**
- Modify: `macgit/Services/SyncState.swift`
- Create: `macgitTests/GitUndoRemoteIntegrationTests.swift`

- [ ] **Step 1: Register pull undo**

In `SyncState.performPull`, before `GitStatusService.shared.pull`, add:

```swift
let oldHead = await GitStatusService.shared.tipHash(for: "HEAD", in: repositoryURL)
```

After successful pull and refresh, add:

```swift
if let oldHead,
   let newHead = await GitStatusService.shared.tipHash(for: "HEAD", in: repositoryURL),
   oldHead != newHead {
    undoManager?.register(
        GitUndoEntry(
            repositoryURL: repositoryURL,
            label: "Pull",
            undoOperation: .resetHead(target: oldHead, mode: .hard, expectedHead: newHead),
            redoOperation: .sequence([
                .resetHead(target: oldHead, mode: .hard, expectedHead: newHead)
            ]),
            confirmationMessage: "Undoing a pull will reset the current branch back to its previous commit. Continue?"
        )
    )
}
```

Update `performPull` signature to accept:

```swift
undoManager: GitUndoManager? = nil
```

Pass the undo manager from `MainWindowView.pullSheet` and branch pull call sites.

- [ ] **Step 2: Register publish-new-branch undo**

In `SyncState.performPush`, after a successful push, for each pushed branch with no upstream before push, add:

```swift
let remoteSupport = GitRemoteUndoSupport()
if let remoteHash = try await remoteSupport.remoteHash(remote: options.remote, branch: remoteBranch, in: repositoryURL) {
    undoManager?.register(
        GitUndoEntry(
            repositoryURL: repositoryURL,
            label: "Publish \(remoteBranch)",
            undoOperation: .deleteRemoteBranch(remote: options.remote, branch: remoteBranch, expectedHash: remoteHash),
            redoOperation: .sequence([]),
            confirmationMessage: "Undoing publish will delete '\(options.remote)/\(remoteBranch)' from the remote. Continue?"
        )
    )
}
```

Update `performPush` signature to accept:

```swift
undoManager: GitUndoManager? = nil
```

Pass the undo manager from `MainWindowView.pushSheet`.

- [ ] **Step 3: Write remote integration test**

Create `macgitTests/GitUndoRemoteIntegrationTests.swift`:

```swift
import XCTest
@testable import macgit

final class GitUndoRemoteIntegrationTests: XCTestCase {
    func testDeleteRemoteBranchOperationRemovesPublishedBranchWhenHashMatches() async throws {
        let fixture = try makeFixtureWithFeatureBranch()
        let support = GitRemoteUndoSupport()
        let hash = try XCTUnwrap(try await support.remoteHash(remote: "origin", branch: "feature", in: fixture.cloneURL))
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
```

- [ ] **Step 4: Run remote tests and build**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitRemoteUndoSupportTests -only-testing:macgitTests/GitUndoRemoteIntegrationTests
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: tests pass and app builds.

- [ ] **Step 5: Commit**

Run:

```bash
git add macgit/Services/SyncState.swift macgitTests/GitUndoRemoteIntegrationTests.swift
git commit -m "feat: record guarded undo entries for remote actions"
```

Expected: commit succeeds.

## Self-Review

Spec coverage:

- Pull undo and publish-new-branch undo are planned.
- Existing-branch push rewrite is explicitly excluded.

Placeholder scan:

- Confirmation, hash checks, command execution, and tests are concrete.

Type consistency:

- `confirmationMessage` is added to `GitUndoEntry` before `MainWindowView` and remote registrations use it.
