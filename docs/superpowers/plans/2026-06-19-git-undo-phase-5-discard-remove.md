# Git Undo Phase 5 Discard and Remove Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add undo and redo for discard/remove file actions and discard hunk/line actions without relying on Git reflog.

**Architecture:** File-level destructive actions capture repository-local snapshots under `.git/macgit/undo/<id>` before running. Hunk/line discard reuses patch-based undo from Phase 1B because the exact discarded patch can be reapplied to the working tree.

**Tech Stack:** Swift 6, SwiftUI, XCTest, `xcodebuild`, `FileManager`, JSON `Codable`, `git apply`.

---

## Prerequisite

Complete and merge Phase 1B. This phase depends on `GitUndoOperation.applyPatch` for hunk and line discard undo.

## Scope

This phase supports:

- File-level discard from `FileStatusView`.
- File-level remove from `FileStatusView`.
- Hunk-level and selected-line discard from `DiffView`.

This phase does not support "discard all working copy" because macgit does not currently expose that action as a primary command.

## File Structure

- Create `macgit/Services/GitFileUndoSnapshotStore.swift`: captures and restores file snapshots under `.git/macgit/undo`.
- Create `macgit/Services/GitFileUndoSnapshotModels.swift`: codable manifest models.
- Modify `macgit/Services/GitUndoModels.swift`: add file snapshot restore/delete operations.
- Modify `macgit/Services/GitUndoExecutor.swift`: execute snapshot restore/delete.
- Modify `macgit/Views/FileStatus/FileStatusView.swift`: capture snapshots before discard/remove and register undo entries.
- Modify `macgit/Views/Common/DiffView.swift`: register undo entries for hunk/line discard.
- Create `macgitTests/GitFileUndoSnapshotStoreTests.swift`: pure snapshot store tests.
- Create `macgitTests/GitUndoDiscardRemoveIntegrationTests.swift`: real-repo discard/remove undo tests.

## Task 1: Add File Snapshot Store

**Files:**
- Create: `macgit/Services/GitFileUndoSnapshotModels.swift`
- Create: `macgit/Services/GitFileUndoSnapshotStore.swift`
- Create: `macgitTests/GitFileUndoSnapshotStoreTests.swift`

- [ ] **Step 1: Write failing snapshot store tests**

Create `macgitTests/GitFileUndoSnapshotStoreTests.swift`:

```swift
import XCTest
@testable import macgit

final class GitFileUndoSnapshotStoreTests: XCTestCase {
    func testCaptureAndRestoreExistingFile() throws {
        let repoURL = try makeRepoDirectory()
        let fileURL = repoURL.appendingPathComponent("Notes.txt")
        try "before\n".write(to: fileURL, atomically: true, encoding: .utf8)
        let store = GitFileUndoSnapshotStore()

        let snapshot = try store.capture(paths: ["Notes.txt"], in: repoURL)
        try "after\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try store.restore(snapshotID: snapshot.id, in: repoURL)

        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "before\n")
    }

    func testCaptureAndRestoreMissingFileRemovesCurrentFile() throws {
        let repoURL = try makeRepoDirectory()
        let store = GitFileUndoSnapshotStore()

        let snapshot = try store.capture(paths: ["Missing.txt"], in: repoURL)
        try "created later\n".write(to: repoURL.appendingPathComponent("Missing.txt"), atomically: true, encoding: .utf8)
        try store.restore(snapshotID: snapshot.id, in: repoURL)

        XCTAssertFalse(FileManager.default.fileExists(atPath: repoURL.appendingPathComponent("Missing.txt").path))
    }

    private func makeRepoDirectory() throws -> URL {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-file-snapshot-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoURL.appendingPathComponent(".git"), withIntermediateDirectories: true)
        return repoURL
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitFileUndoSnapshotStoreTests
```

Expected: compilation fails with missing `GitFileUndoSnapshotStore`.

- [ ] **Step 3: Add snapshot models**

Create `macgit/Services/GitFileUndoSnapshotModels.swift`:

```swift
//
//  GitFileUndoSnapshotModels.swift
//  macgit
//

import Foundation

struct GitFileUndoSnapshot: Codable, Equatable {
    let id: UUID
    let items: [GitFileUndoSnapshotItem]
}

struct GitFileUndoSnapshotItem: Codable, Equatable {
    let path: String
    let existed: Bool
    let backupRelativePath: String?
}
```

- [ ] **Step 4: Add snapshot store**

Create `macgit/Services/GitFileUndoSnapshotStore.swift`:

```swift
//
//  GitFileUndoSnapshotStore.swift
//  macgit
//

import Foundation

struct GitFileUndoSnapshotStore {
    private let fileManager = FileManager.default

    func capture(paths: [String], in repositoryURL: URL) throws -> GitFileUndoSnapshot {
        let snapshotID = UUID()
        let directory = snapshotDirectory(snapshotID, in: repositoryURL)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let items = try paths.map { path in
            let source = repositoryURL.appendingPathComponent(path)
            guard fileManager.fileExists(atPath: source.path) else {
                return GitFileUndoSnapshotItem(path: path, existed: false, backupRelativePath: nil)
            }

            let backupRelativePath = "files/\(path)"
            let backupURL = directory.appendingPathComponent(backupRelativePath)
            try fileManager.createDirectory(at: backupURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            try fileManager.copyItem(at: source, to: backupURL)
            return GitFileUndoSnapshotItem(path: path, existed: true, backupRelativePath: backupRelativePath)
        }

        let snapshot = GitFileUndoSnapshot(id: snapshotID, items: items)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: manifestURL(snapshotID, in: repositoryURL), options: .atomic)
        return snapshot
    }

    func restore(snapshotID: UUID, in repositoryURL: URL) throws {
        let data = try Data(contentsOf: manifestURL(snapshotID, in: repositoryURL))
        let snapshot = try JSONDecoder().decode(GitFileUndoSnapshot.self, from: data)

        for item in snapshot.items {
            let destination = repositoryURL.appendingPathComponent(item.path)
            if item.existed, let backupRelativePath = item.backupRelativePath {
                let backup = snapshotDirectory(snapshotID, in: repositoryURL).appendingPathComponent(backupRelativePath)
                try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.copyItem(at: backup, to: destination)
            } else if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
        }
    }

    func delete(snapshotID: UUID, in repositoryURL: URL) throws {
        let directory = snapshotDirectory(snapshotID, in: repositoryURL)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
    }

    private func undoRoot(in repositoryURL: URL) -> URL {
        repositoryURL.appendingPathComponent(".git/macgit/undo", isDirectory: true)
    }

    private func snapshotDirectory(_ id: UUID, in repositoryURL: URL) -> URL {
        undoRoot(in: repositoryURL).appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func manifestURL(_ id: UUID, in repositoryURL: URL) -> URL {
        snapshotDirectory(id, in: repositoryURL).appendingPathComponent("manifest.json")
    }
}
```

- [ ] **Step 5: Run snapshot tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitFileUndoSnapshotStoreTests
```

Expected: tests pass.

- [ ] **Step 6: Commit**

Run:

```bash
git add macgit/Services/GitFileUndoSnapshotModels.swift macgit/Services/GitFileUndoSnapshotStore.swift macgitTests/GitFileUndoSnapshotStoreTests.swift
git commit -m "feat: add file undo snapshot store"
```

Expected: commit succeeds.

## Task 2: Execute File Snapshot Undo Operations

**Files:**
- Modify: `macgit/Services/GitUndoModels.swift`
- Modify: `macgit/Services/GitUndoExecutor.swift`

- [ ] **Step 1: Add snapshot operations**

In `GitUndoOperation`, add:

```swift
case restoreFileSnapshot(id: UUID)
case deleteFileSnapshot(id: UUID)
```

- [ ] **Step 2: Add snapshot store to executor**

In `GitUndoExecutor`, add:

```swift
private let snapshotStore: GitFileUndoSnapshotStore
```

Update initializer with:

```swift
snapshotStore: GitFileUndoSnapshotStore = GitFileUndoSnapshotStore()
```

and assign it:

```swift
self.snapshotStore = snapshotStore
```

Add executor cases:

```swift
case .restoreFileSnapshot(let id):
    try snapshotStore.restore(snapshotID: id, in: repositoryURL)
case .deleteFileSnapshot(let id):
    try snapshotStore.delete(snapshotID: id, in: repositoryURL)
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
git commit -m "feat: execute file snapshot undo operations"
```

Expected: commit succeeds.

## Task 3: Register File-Level Discard and Remove Undo

**Files:**
- Modify: `macgit/Views/FileStatus/FileStatusView.swift`
- Create: `macgitTests/GitUndoDiscardRemoveIntegrationTests.swift`

- [ ] **Step 1: Add discard/remove file operations**

In `GitUndoOperation`, add:

```swift
case discardFiles(paths: [String])
case removeFiles(paths: [String])
```

In `GitUndoExecutor.execute(_:in:)`, add:

```swift
case .discardFiles(let paths):
    for path in paths {
        _ = try await runner.runGit(arguments: ["checkout", "--", path], in: repositoryURL)
    }
case .removeFiles(let paths):
    for path in paths {
        _ = try await runner.runGit(arguments: ["rm", "-f", path], in: repositoryURL)
    }
```

- [ ] **Step 2: Register discard snapshots**

In `FileStatusView.discard(files:)`, before the `do` block, add:

```swift
let paths = files.map(\.path)
let snapshotStore = GitFileUndoSnapshotStore()
```

Inside the `do` block, before the loop, add:

```swift
let snapshot = try snapshotStore.capture(paths: paths, in: repositoryURL)
```

After the loop succeeds, before `await loadStatus()`, add:

```swift
await MainActor.run {
    undoManager?.register(
        GitUndoEntry(
            repositoryURL: repositoryURL,
            label: paths.count == 1 ? "Discard \((paths[0] as NSString).lastPathComponent)" : "Discard \(paths.count) files",
            undoOperation: .restoreFileSnapshot(id: snapshot.id),
            redoOperation: .discardFiles(paths: paths)
        )
    )
}
```

- [ ] **Step 3: Register remove snapshots**

In `FileStatusView.remove(files:)`, capture snapshots in the same shape as discard, then register:

```swift
undoManager?.register(
    GitUndoEntry(
        repositoryURL: repositoryURL,
        label: paths.count == 1 ? "Remove \((paths[0] as NSString).lastPathComponent)" : "Remove \(paths.count) files",
        undoOperation: .restoreFileSnapshot(id: snapshot.id),
        redoOperation: .removeFiles(paths: paths)
    )
)
```

- [ ] **Step 4: Write real-repo discard/remove tests**

Create `macgitTests/GitUndoDiscardRemoveIntegrationTests.swift`:

```swift
import XCTest
@testable import macgit

final class GitUndoDiscardRemoveIntegrationTests: XCTestCase {
    func testSnapshotRestoresDiscardedTrackedFile() async throws {
        let repoURL = try makeTempRepo()
        let fileURL = repoURL.appendingPathComponent("tracked.txt")
        try "changed\n".write(to: fileURL, atomically: true, encoding: .utf8)
        let store = GitFileUndoSnapshotStore()
        let snapshot = try store.capture(paths: ["tracked.txt"], in: repoURL)
        let file = StatusFile(path: "tracked.txt", status: .modified, originalPath: nil)
        try await GitStatusService.shared.discard(file: file, in: repoURL)

        try store.restore(snapshotID: snapshot.id, in: repoURL)

        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "changed\n")
    }

    func testSnapshotRestoresRemovedUntrackedFile() async throws {
        let repoURL = try makeTempRepo()
        let fileURL = repoURL.appendingPathComponent("new.txt")
        try "new\n".write(to: fileURL, atomically: true, encoding: .utf8)
        let store = GitFileUndoSnapshotStore()
        let snapshot = try store.capture(paths: ["new.txt"], in: repoURL)
        let file = StatusFile(path: "new.txt", status: .untracked, originalPath: nil)
        try await GitStatusService.shared.remove(file: file, in: repoURL)

        try store.restore(snapshotID: snapshot.id, in: repoURL)

        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "new\n")
    }

    private func makeTempRepo() throws -> URL {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-undo-discard-remove-\(UUID().uuidString)", isDirectory: true)
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

- [ ] **Step 5: Run tests and build**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitFileUndoSnapshotStoreTests -only-testing:macgitTests/GitUndoDiscardRemoveIntegrationTests
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: tests pass and app builds.

- [ ] **Step 6: Commit**

Run:

```bash
git add macgit/Services/GitUndoModels.swift macgit/Services/GitUndoExecutor.swift macgit/Views/FileStatus/FileStatusView.swift macgitTests/GitUndoDiscardRemoveIntegrationTests.swift
git commit -m "feat: record undo entries for file discard and remove"
```

Expected: commit succeeds.

## Task 4: Register Hunk and Line Discard Undo

**Files:**
- Modify: `macgit/Views/Common/DiffView.swift`

- [ ] **Step 1: Replace direct discard hunk calls**

For hunk discard actions, replace:

```swift
try await GitStatusService.shared.discard(hunk: hunk, file: file!, in: repositoryURL!)
```

with:

```swift
let patch = DiffPatchBuilder.patchString(for: hunk, filePath: file!.path)
performPatchAction(label: "Discard hunk in \(file!.displayName)", patch: patch, cached: false, reverse: true)
```

This produces undo `.applyPatch(patch: patch, cached: false, reverse: false)` and redo `.applyPatch(patch: patch, cached: false, reverse: true)` through the existing `performPatchAction` helper from Phase 1B.

- [ ] **Step 2: Replace direct discard selected-line calls**

For selected-line discard actions, replace:

```swift
try await GitStatusService.shared.discard(lines: lines, hunk: hunk, file: file!, in: repositoryURL!)
```

with:

```swift
let lines = expandedSelectedLines(for: hunk)
let patch = DiffPatchBuilder.patchString(for: hunk, selectedLines: lines, filePath: file!.path)
performPatchAction(label: "Discard selected lines in \(file!.displayName)", patch: patch, cached: false, reverse: true)
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
git add macgit/Views/Common/DiffView.swift
git commit -m "feat: record undo entries for patch discard"
```

Expected: commit succeeds.

## Self-Review

Spec coverage:

- File discard/remove has snapshot-based undo.
- Hunk/line discard has patch-based undo.

Placeholder scan:

- All capture, restore, registration, and commands are explicit.

Type consistency:

- Snapshot operation cases match executor and UI snippets.
