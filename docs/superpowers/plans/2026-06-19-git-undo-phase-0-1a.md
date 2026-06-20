# Git Undo Phase 0 and 1A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first safe Undo slice for macgit: a reusable Git undo stack plus Cmd+Z / Shift+Cmd+Z support for file-level stage and unstage actions.

**Architecture:** Add a runtime-only `GitUndoManager` owned by each `MainWindowView`, with concrete `GitUndoOperation` values instead of generic closures. A small `GitUndoExecutor` translates undo/redo operations into semantic Git commands, and `FileStatusView` registers undo entries only after stage/unstage actions succeed.

**Tech Stack:** Swift 6, SwiftUI commands and notifications, XCTest, `xcodebuild`, existing `GitStatusService`.

---

## Scope

This plan implements only:

- Phase 0: Undo/redo infrastructure, menu wiring, repository refresh after undo/redo.
- Phase 1A: file-level stage and unstage from `FileStatusView`, including single-file, selected-files, and all-files paths.

This plan intentionally excludes discard/remove, hunk/line actions, commits, stashes, branches, merges, rebases, pulls, pushes, and remote operations. Those actions need their own plans because they require stronger snapshots or remote safety checks.

## File Structure

Create these files:

- `macgit/Services/GitUndoModels.swift`: `GitUndoOperation`, `GitUndoEntry`, `GitUndoEntryFactory`, and `GitUndoManager`.
- `macgit/Services/GitCommandRunning.swift`: small protocol that lets `GitUndoExecutor` use `GitStatusService` in production and a recording fake in tests.
- `macgit/Services/GitUndoExecutor.swift`: translates concrete undo operations into Git commands.
- `macgit/App/GitUndoMenuAction.swift`: notification payload for app-level Undo and Redo menu commands.
- `macgitTests/GitUndoManagerTests.swift`: stack behavior and entry factory tests.
- `macgitTests/GitUndoExecutorTests.swift`: command-building tests with a fake Git runner.
- `macgitTests/GitUndoStageIntegrationTests.swift`: temp-repo tests proving stage/unstage operations undo and redo real Git state.

Modify these files:

- `macgit/Views/MainWindow/MainWindowView.swift`: own the undo manager, pass it to `FileStatusView`, listen for undo menu notifications, execute undo/redo, refresh state.
- `macgit/Views/FileStatus/FileStatusView.swift`: accept an optional undo manager and register entries after successful stage/unstage.
- `macgit/App/macgitApp.swift`: replace the default Undo/Redo command group with Git-aware notification commands.

## Task 1: Add Undo Models and Stack Manager

**Files:**
- Create: `macgit/Services/GitUndoModels.swift`
- Create: `macgitTests/GitUndoManagerTests.swift`

- [ ] **Step 1: Write the failing manager and factory tests**

Create `macgitTests/GitUndoManagerTests.swift`:

```swift
import XCTest
@testable import macgit

@MainActor
final class GitUndoManagerTests: XCTestCase {
    func testRegisterAddsUndoEntryAndClearsRedoStack() {
        let manager = GitUndoManager()
        let first = entry(label: "Stage README.md")
        let second = entry(label: "Stage App.swift")

        manager.register(first)
        let popped = manager.popForUndo()
        XCTAssertEqual(popped, first)
        manager.completeUndo(first)
        XCTAssertEqual(manager.redoStack, [first])

        manager.register(second)

        XCTAssertEqual(manager.undoStack, [second])
        XCTAssertTrue(manager.redoStack.isEmpty)
        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
        XCTAssertEqual(manager.undoTitle, "Undo Stage App.swift")
        XCTAssertEqual(manager.redoTitle, "Redo Git Action")
    }

    func testUndoAndRedoStackTransitionsPreserveEntryOrder() {
        let manager = GitUndoManager()
        let first = entry(label: "Stage README.md")
        let second = entry(label: "Unstage App.swift")

        manager.register(first)
        manager.register(second)

        XCTAssertEqual(manager.popForUndo(), second)
        manager.completeUndo(second)
        XCTAssertEqual(manager.undoStack, [first])
        XCTAssertEqual(manager.redoStack, [second])
        XCTAssertEqual(manager.popForRedo(), second)
        manager.completeRedo(second)
        XCTAssertEqual(manager.undoStack, [first, second])
        XCTAssertTrue(manager.redoStack.isEmpty)
    }

    func testFailedUndoRestoresEntryToUndoStack() {
        let manager = GitUndoManager()
        let first = entry(label: "Stage README.md")
        let second = entry(label: "Stage App.swift")

        manager.register(first)
        manager.register(second)

        let popped = manager.popForUndo()
        XCTAssertEqual(popped, second)
        manager.restoreUndo(second)

        XCTAssertEqual(manager.undoStack, [first, second])
        XCTAssertTrue(manager.redoStack.isEmpty)
    }

    func testFailedRedoRestoresEntryToRedoStack() {
        let manager = GitUndoManager()
        let first = entry(label: "Stage README.md")

        manager.register(first)
        let popped = manager.popForUndo()
        XCTAssertEqual(popped, first)
        manager.completeUndo(first)

        let redo = manager.popForRedo()
        XCTAssertEqual(redo, first)
        manager.restoreRedo(first)

        XCTAssertTrue(manager.undoStack.isEmpty)
        XCTAssertEqual(manager.redoStack, [first])
    }

    func testFactoryBuildsStageAndUnstageEntriesWithStablePathOrder() {
        let repoURL = URL(fileURLWithPath: "/tmp/repo")
        let stage = GitUndoEntryFactory.stageFiles(
            repositoryURL: repoURL,
            paths: ["Sources/App.swift", "README.md", "Sources/App.swift"]
        )
        let unstage = GitUndoEntryFactory.unstageFiles(
            repositoryURL: repoURL,
            paths: ["README.md"]
        )

        XCTAssertEqual(stage.repositoryURL, repoURL)
        XCTAssertEqual(stage.label, "Stage 2 files")
        XCTAssertEqual(stage.undoOperation, .unstageFiles(paths: ["Sources/App.swift", "README.md"]))
        XCTAssertEqual(stage.redoOperation, .stageFiles(paths: ["Sources/App.swift", "README.md"]))

        XCTAssertEqual(unstage.label, "Unstage README.md")
        XCTAssertEqual(unstage.undoOperation, .stageFiles(paths: ["README.md"]))
        XCTAssertEqual(unstage.redoOperation, .unstageFiles(paths: ["README.md"]))
    }

    private func entry(label: String) -> GitUndoEntry {
        GitUndoEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            repositoryURL: URL(fileURLWithPath: "/tmp/repo"),
            label: label,
            undoOperation: .unstageFiles(paths: ["README.md"]),
            redoOperation: .stageFiles(paths: ["README.md"])
        )
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitUndoManagerTests
```

Expected: the test target fails to compile with errors such as `cannot find 'GitUndoManager' in scope` and `cannot find 'GitUndoEntryFactory' in scope`.

- [ ] **Step 3: Add the undo model and manager**

Create `macgit/Services/GitUndoModels.swift`:

```swift
//
//  GitUndoModels.swift
//  macgit
//

import Foundation
import SwiftUI

enum GitUndoOperation: Equatable {
    case stageFiles(paths: [String])
    case unstageFiles(paths: [String])
}

struct GitUndoEntry: Identifiable, Equatable {
    let id: UUID
    let repositoryURL: URL
    let label: String
    let undoOperation: GitUndoOperation
    let redoOperation: GitUndoOperation

    init(
        id: UUID = UUID(),
        repositoryURL: URL,
        label: String,
        undoOperation: GitUndoOperation,
        redoOperation: GitUndoOperation
    ) {
        self.id = id
        self.repositoryURL = repositoryURL
        self.label = label
        self.undoOperation = undoOperation
        self.redoOperation = redoOperation
    }
}

enum GitUndoEntryFactory {
    static func stageFiles(repositoryURL: URL, paths: [String]) -> GitUndoEntry {
        let normalizedPaths = normalized(paths)
        return GitUndoEntry(
            repositoryURL: repositoryURL,
            label: label(verb: "Stage", paths: normalizedPaths),
            undoOperation: .unstageFiles(paths: normalizedPaths),
            redoOperation: .stageFiles(paths: normalizedPaths)
        )
    }

    static func unstageFiles(repositoryURL: URL, paths: [String]) -> GitUndoEntry {
        let normalizedPaths = normalized(paths)
        return GitUndoEntry(
            repositoryURL: repositoryURL,
            label: label(verb: "Unstage", paths: normalizedPaths),
            undoOperation: .stageFiles(paths: normalizedPaths),
            redoOperation: .unstageFiles(paths: normalizedPaths)
        )
    }

    private static func normalized(_ paths: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for path in paths where !path.isEmpty {
            if seen.insert(path).inserted {
                result.append(path)
            }
        }
        return result
    }

    private static func label(verb: String, paths: [String]) -> String {
        if paths.count == 1, let path = paths.first {
            return "\(verb) \((path as NSString).lastPathComponent)"
        }
        return "\(verb) \(paths.count) files"
    }
}

@MainActor
final class GitUndoManager: ObservableObject {
    @Published private(set) var undoStack: [GitUndoEntry] = []
    @Published private(set) var redoStack: [GitUndoEntry] = []

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    var undoTitle: String {
        guard let entry = undoStack.last else { return "Undo Git Action" }
        return "Undo \(entry.label)"
    }

    var redoTitle: String {
        guard let entry = redoStack.last else { return "Redo Git Action" }
        return "Redo \(entry.label)"
    }

    func register(_ entry: GitUndoEntry) {
        undoStack.append(entry)
        redoStack.removeAll()
    }

    func popForUndo() -> GitUndoEntry? {
        undoStack.popLast()
    }

    func completeUndo(_ entry: GitUndoEntry) {
        redoStack.append(entry)
    }

    func restoreUndo(_ entry: GitUndoEntry) {
        undoStack.append(entry)
    }

    func popForRedo() -> GitUndoEntry? {
        redoStack.popLast()
    }

    func completeRedo(_ entry: GitUndoEntry) {
        undoStack.append(entry)
    }

    func restoreRedo(_ entry: GitUndoEntry) {
        redoStack.append(entry)
    }

    func removeAll() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
```

- [ ] **Step 4: Run the manager tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitUndoManagerTests
```

Expected: `GitUndoManagerTests` passes with 5 tests.

- [ ] **Step 5: Commit**

Run:

```bash
git add macgit/Services/GitUndoModels.swift macgitTests/GitUndoManagerTests.swift
git commit -m "feat: add git undo stack models"
```

Expected: commit succeeds.

## Task 2: Add Git Undo Executor

**Files:**
- Create: `macgit/Services/GitCommandRunning.swift`
- Create: `macgit/Services/GitUndoExecutor.swift`
- Create: `macgitTests/GitUndoExecutorTests.swift`

- [ ] **Step 1: Write the failing executor tests**

Create `macgitTests/GitUndoExecutorTests.swift`:

```swift
import XCTest
@testable import macgit

final class GitUndoExecutorTests: XCTestCase {
    func testStageFilesRunsGitAddWithPathspecSeparator() async throws {
        let runner = RecordingGitRunner()
        let executor = GitUndoExecutor(runner: runner)
        let repoURL = URL(fileURLWithPath: "/tmp/repo")

        try await executor.execute(.stageFiles(paths: ["README.md", "Sources/App.swift"]), in: repoURL)

        let calls = await runner.recordedCalls()
        XCTAssertEqual(calls, [
            GitCommandCall(
                arguments: ["add", "--", "README.md", "Sources/App.swift"],
                directory: repoURL
            )
        ])
    }

    func testUnstageFilesRunsGitResetHeadWithPathspecSeparator() async throws {
        let runner = RecordingGitRunner()
        let executor = GitUndoExecutor(runner: runner)
        let repoURL = URL(fileURLWithPath: "/tmp/repo")

        try await executor.execute(.unstageFiles(paths: ["README.md"]), in: repoURL)

        let calls = await runner.recordedCalls()
        XCTAssertEqual(calls, [
            GitCommandCall(
                arguments: ["reset", "HEAD", "--", "README.md"],
                directory: repoURL
            )
        ])
    }

    func testEmptyPathListThrowsBeforeRunningGit() async throws {
        let runner = RecordingGitRunner()
        let executor = GitUndoExecutor(runner: runner)
        let repoURL = URL(fileURLWithPath: "/tmp/repo")

        do {
            try await executor.execute(.stageFiles(paths: []), in: repoURL)
            XCTFail("Expected emptyPathList error")
        } catch let error as GitUndoError {
            XCTAssertEqual(error, .emptyPathList)
        }

        let calls = await runner.recordedCalls()
        XCTAssertTrue(calls.isEmpty)
    }
}

private struct GitCommandCall: Equatable {
    let arguments: [String]
    let directory: URL
}

private actor RecordingGitRunner: GitCommandRunning {
    private var calls: [GitCommandCall] = []

    func runGit(arguments: [String], in directory: URL) async throws -> String {
        calls.append(GitCommandCall(arguments: arguments, directory: directory))
        return ""
    }

    func recordedCalls() -> [GitCommandCall] {
        calls
    }
}
```

- [ ] **Step 2: Run the executor tests to verify they fail**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitUndoExecutorTests
```

Expected: the test target fails to compile with errors such as `cannot find type 'GitCommandRunning' in scope`, `cannot find 'GitUndoExecutor' in scope`, and `cannot find 'GitUndoError' in scope`.

- [ ] **Step 3: Add the Git command protocol**

Create `macgit/Services/GitCommandRunning.swift`:

```swift
//
//  GitCommandRunning.swift
//  macgit
//

import Foundation

protocol GitCommandRunning {
    func runGit(arguments: [String], in directory: URL) async throws -> String
}

extension GitStatusService: GitCommandRunning {}
```

- [ ] **Step 4: Add the executor**

Create `macgit/Services/GitUndoExecutor.swift`:

```swift
//
//  GitUndoExecutor.swift
//  macgit
//

import Foundation

enum GitUndoError: LocalizedError, Equatable {
    case emptyPathList

    var errorDescription: String? {
        switch self {
        case .emptyPathList:
            return "Cannot undo this Git action because it does not contain any file paths."
        }
    }
}

struct GitUndoExecutor {
    private let runner: any GitCommandRunning

    init(runner: any GitCommandRunning = GitStatusService.shared) {
        self.runner = runner
    }

    func execute(_ operation: GitUndoOperation, in repositoryURL: URL) async throws {
        switch operation {
        case .stageFiles(let paths):
            try await runFileCommand(["add", "--"], paths: paths, in: repositoryURL)
        case .unstageFiles(let paths):
            try await runFileCommand(["reset", "HEAD", "--"], paths: paths, in: repositoryURL)
        }
    }

    private func runFileCommand(_ prefix: [String], paths: [String], in repositoryURL: URL) async throws {
        guard !paths.isEmpty else {
            throw GitUndoError.emptyPathList
        }
        var arguments = prefix
        arguments.append(contentsOf: paths)
        _ = try await runner.runGit(arguments: arguments, in: repositoryURL)
    }
}
```

- [ ] **Step 5: Run the executor tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitUndoExecutorTests
```

Expected: `GitUndoExecutorTests` passes with 3 tests.

- [ ] **Step 6: Commit**

Run:

```bash
git add macgit/Services/GitCommandRunning.swift macgit/Services/GitUndoExecutor.swift macgitTests/GitUndoExecutorTests.swift
git commit -m "feat: execute file-level git undo operations"
```

Expected: commit succeeds.

## Task 3: Verify Stage and Unstage Against a Real Git Repository

**Files:**
- Create: `macgitTests/GitUndoStageIntegrationTests.swift`

- [ ] **Step 1: Write real-repo integration tests**

Create `macgitTests/GitUndoStageIntegrationTests.swift`:

```swift
import XCTest
@testable import macgit

final class GitUndoStageIntegrationTests: XCTestCase {
    func testExecutorStagesAndUnstagesTrackedFileInRealRepo() async throws {
        let repoURL = try makeTempRepo()
        let fileURL = repoURL.appendingPathComponent("tracked.txt")
        try "changed\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let executor = GitUndoExecutor()
        try await executor.execute(.stageFiles(paths: ["tracked.txt"]), in: repoURL)

        var status = try await GitStatusService.shared.status(for: repoURL)
        XCTAssertTrue(status.staged.contains { $0.path == "tracked.txt" })
        XCTAssertFalse(status.unstaged.contains { $0.path == "tracked.txt" })

        try await executor.execute(.unstageFiles(paths: ["tracked.txt"]), in: repoURL)

        status = try await GitStatusService.shared.status(for: repoURL)
        XCTAssertFalse(status.staged.contains { $0.path == "tracked.txt" })
        XCTAssertTrue(status.unstaged.contains { $0.path == "tracked.txt" })
    }

    func testExecutorStagesAndUnstagesUntrackedFileInRealRepo() async throws {
        let repoURL = try makeTempRepo()
        let fileURL = repoURL.appendingPathComponent("new.txt")
        try "new file\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let executor = GitUndoExecutor()
        try await executor.execute(.stageFiles(paths: ["new.txt"]), in: repoURL)

        var status = try await GitStatusService.shared.status(for: repoURL)
        XCTAssertTrue(status.staged.contains { $0.path == "new.txt" })
        XCTAssertFalse(status.untracked.contains { $0.path == "new.txt" })

        try await executor.execute(.unstageFiles(paths: ["new.txt"]), in: repoURL)

        status = try await GitStatusService.shared.status(for: repoURL)
        XCTAssertFalse(status.staged.contains { $0.path == "new.txt" })
        XCTAssertTrue(status.untracked.contains { $0.path == "new.txt" })
    }

    private func makeTempRepo() throws -> URL {
        let repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macgit-undo-stage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)

        try runGit(["init", "-b", "main"], in: repoURL)
        try runGit(["config", "user.name", "Mac Git Tests"], in: repoURL)
        try runGit(["config", "user.email", "tests@example.com"], in: repoURL)

        let trackedFile = repoURL.appendingPathComponent("tracked.txt")
        try "base\n".write(to: trackedFile, atomically: true, encoding: .utf8)
        try runGit(["add", "tracked.txt"], in: repoURL)
        try runGit(["commit", "-m", "initial commit"], in: repoURL)

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
            let outputData = stderr.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? "git failed"
            XCTFail("git \(arguments.joined(separator: " ")) failed: \(output)")
        }
    }
}
```

- [ ] **Step 2: Run the integration tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitUndoStageIntegrationTests
```

Expected: `GitUndoStageIntegrationTests` passes with 2 tests.

- [ ] **Step 3: Commit**

Run:

```bash
git add macgitTests/GitUndoStageIntegrationTests.swift
git commit -m "test: verify git undo stage operations in real repos"
```

Expected: commit succeeds.

## Task 4: Register Stage and Unstage Entries from FileStatusView

**Files:**
- Modify: `macgit/Views/FileStatus/FileStatusView.swift`
- Modify: `macgit/Views/MainWindow/MainWindowView.swift`

- [ ] **Step 1: Add an undo manager dependency to FileStatusView**

In `macgit/Views/FileStatus/FileStatusView.swift`, change the stored properties near the top from:

```swift
struct FileStatusView: View {
    let repositoryURL: URL
    var syncState: SyncState? = nil
```

to:

```swift
struct FileStatusView: View {
    let repositoryURL: URL
    var syncState: SyncState? = nil
    var undoManager: GitUndoManager? = nil
```

- [ ] **Step 2: Register undo entries after successful stage actions**

In `macgit/Views/FileStatus/FileStatusView.swift`, replace the existing `stage(files:)` function with:

```swift
private func stage(files: [StatusFile]) async {
    guard !files.isEmpty else { return }
    let paths = files.map(\.path)
    do {
        try await GitStatusService.shared.stageAll(files: files, in: repositoryURL)
        await MainActor.run {
            undoManager?.register(
                GitUndoEntryFactory.stageFiles(
                    repositoryURL: repositoryURL,
                    paths: paths
                )
            )
        }
        await loadStatus()
        await syncState?.refresh(repositoryURL: repositoryURL)
    } catch {
        errorMessage = error.localizedDescription
        showingError = true
    }
}
```

- [ ] **Step 3: Register undo entries after successful unstage actions**

In `macgit/Views/FileStatus/FileStatusView.swift`, replace the existing `unstage(files:)` function with:

```swift
private func unstage(files: [StatusFile]) async {
    guard !files.isEmpty else { return }
    let paths = files.map(\.path)
    do {
        try await GitStatusService.shared.unstageAll(files: files, in: repositoryURL)
        await MainActor.run {
            undoManager?.register(
                GitUndoEntryFactory.unstageFiles(
                    repositoryURL: repositoryURL,
                    paths: paths
                )
            )
        }
        await loadStatus()
        await syncState?.refresh(repositoryURL: repositoryURL)
    } catch {
        errorMessage = error.localizedDescription
        showingError = true
    }
}
```

- [ ] **Step 4: Own and pass the undo manager from MainWindowView**

In `macgit/Views/MainWindow/MainWindowView.swift`, add this state property beside the existing `syncState`:

```swift
@StateObject private var undoManager = GitUndoManager()
```

In the `detailPane`, replace the current file-status destination:

```swift
FileStatusView(repositoryURL: repositoryURL, syncState: syncState)
```

with:

```swift
FileStatusView(
    repositoryURL: repositoryURL,
    syncState: syncState,
    undoManager: undoManager
)
```

- [ ] **Step 5: Build to verify SwiftUI integration compiles**

Run:

```bash
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: build succeeds.

- [ ] **Step 6: Commit**

Run:

```bash
git add macgit/Views/FileStatus/FileStatusView.swift macgit/Views/MainWindow/MainWindowView.swift
git commit -m "feat: record undo entries for staging actions"
```

Expected: commit succeeds.

## Task 5: Wire Cmd+Z and Shift+Cmd+Z to Git Undo

**Files:**
- Create: `macgit/App/GitUndoMenuAction.swift`
- Modify: `macgit/App/macgitApp.swift`
- Modify: `macgit/Views/MainWindow/MainWindowView.swift`

- [ ] **Step 1: Add the menu notification payload**

Create `macgit/App/GitUndoMenuAction.swift`:

```swift
//
//  GitUndoMenuAction.swift
//  macgit
//

import Foundation

enum GitUndoMenuAction {
    case undo
    case redo
}

extension Notification.Name {
    static let gitUndoAction = Notification.Name("macgit.gitUndoAction")
}
```

- [ ] **Step 2: Replace default Undo/Redo menu commands**

In `macgit/App/macgitApp.swift`, inside the `.commands` block, add this command group before `CommandMenu("Actions")`:

```swift
CommandGroup(replacing: .undoRedo) {
    Button("Undo Git Action") {
        NotificationCenter.default.post(
            name: .gitUndoAction,
            object: nil,
            userInfo: ["action": GitUndoMenuAction.undo]
        )
    }
    .disabled(!appState.hasOpenRepository)
    .keyboardShortcut("z", modifiers: .command)

    Button("Redo Git Action") {
        NotificationCenter.default.post(
            name: .gitUndoAction,
            object: nil,
            userInfo: ["action": GitUndoMenuAction.redo]
        )
    }
    .disabled(!appState.hasOpenRepository)
    .keyboardShortcut("z", modifiers: [.command, .shift])
}
```

- [ ] **Step 3: Add an executor to MainWindowView**

In `macgit/Views/MainWindow/MainWindowView.swift`, add this stored property near the other private constants:

```swift
private let undoExecutor = GitUndoExecutor()
```

- [ ] **Step 4: Listen for Undo menu notifications**

In `macgit/Views/MainWindow/MainWindowView.swift`, add this receiver beside the existing `.toolbarAction` receiver:

```swift
.onReceive(NotificationCenter.default.publisher(for: .gitUndoAction)) { notification in
    if let action = notification.userInfo?["action"] as? GitUndoMenuAction {
        handleGitUndoMenuAction(action)
    }
}
```

- [ ] **Step 5: Add undo/redo handlers**

In `macgit/Views/MainWindow/MainWindowView.swift`, add these methods near `handleToolbarAction(_:)`:

```swift
private func handleGitUndoMenuAction(_ action: GitUndoMenuAction) {
    guard !syncState.isAnySyncing else {
        syncState.showInfo("Wait for the current Git operation to finish before undoing.")
        return
    }

    switch action {
    case .undo:
        guard let entry = undoManager.popForUndo() else {
            syncState.showInfo("Nothing to undo.")
            return
        }
        Task {
            await executeUndoEntry(entry, menuAction: .undo)
        }
    case .redo:
        guard let entry = undoManager.popForRedo() else {
            syncState.showInfo("Nothing to redo.")
            return
        }
        Task {
            await executeUndoEntry(entry, menuAction: .redo)
        }
    }
}

private func executeUndoEntry(_ entry: GitUndoEntry, menuAction: GitUndoMenuAction) async {
    let operation: GitUndoOperation
    switch menuAction {
    case .undo:
        operation = entry.undoOperation
    case .redo:
        operation = entry.redoOperation
    }

    do {
        try await undoExecutor.execute(operation, in: entry.repositoryURL)
        await syncState.refresh(repositoryURL: repositoryURL)
        NotificationCenter.default.post(
            name: .repositoryDidChange,
            object: nil,
            userInfo: ["repositoryURL": repositoryURL]
        )
        await MainActor.run {
            switch menuAction {
            case .undo:
                undoManager.completeUndo(entry)
                syncState.showInfo("Undid \(entry.label).")
            case .redo:
                undoManager.completeRedo(entry)
                syncState.showInfo("Redid \(entry.label).")
            }
        }
    } catch {
        await MainActor.run {
            switch menuAction {
            case .undo:
                undoManager.restoreUndo(entry)
            case .redo:
                undoManager.restoreRedo(entry)
            }
            syncState.showError(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 6: Build to verify command wiring compiles**

Run:

```bash
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: build succeeds. If SwiftUI reports that `.undoRedo` is unavailable for this deployment target, replace `CommandGroup(replacing: .undoRedo)` with `CommandGroup(before: .pasteboard)` and keep the same buttons and shortcuts.

- [ ] **Step 7: Commit**

Run:

```bash
git add macgit/App/GitUndoMenuAction.swift macgit/App/macgitApp.swift macgit/Views/MainWindow/MainWindowView.swift
git commit -m "feat: wire git undo menu actions"
```

Expected: commit succeeds.

## Task 6: Manual QA and Final Verification

**Files:**
- Verify: `macgit/Services/GitUndoModels.swift`
- Verify: `macgit/Services/GitUndoExecutor.swift`
- Verify: `macgit/Views/FileStatus/FileStatusView.swift`
- Verify: `macgit/Views/MainWindow/MainWindowView.swift`
- Verify: `macgit/App/macgitApp.swift`

- [ ] **Step 1: Run focused undo tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/GitUndoManagerTests -only-testing:macgitTests/GitUndoExecutorTests -only-testing:macgitTests/GitUndoStageIntegrationTests
```

Expected: all undo-focused tests pass.

- [ ] **Step 2: Run existing file status selection tests**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' -only-testing:macgitTests/FileStatusActionSelectionTests
```

Expected: existing file status selection tests pass.

- [ ] **Step 3: Run full test suite**

Run:

```bash
xcodebuild test -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: all tests pass.

- [ ] **Step 4: Run full build**

Run:

```bash
xcodebuild build -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS'
```

Expected: app builds successfully.

- [ ] **Step 5: Manual QA in Commit+**

Build and open the app:

```bash
xcodebuild -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' build
open "$(ls -dt ~/Library/Developer/Xcode/DerivedData/macgit-*/Build/Products/Debug/Commit+.app | head -n 1)"
```

Use a disposable repository and verify these flows:

1. Modify a tracked file, stage it from File Status, press `Cmd+Z`, confirm it returns to Changed.
2. Press `Shift+Cmd+Z`, confirm it returns to Staged.
3. Select two changed files, stage selected, press `Cmd+Z`, confirm both return to Changed.
4. Stage an untracked file, press `Cmd+Z`, confirm it returns to Untracked and still exists on disk.
5. Unstage a staged file, press `Cmd+Z`, confirm it returns to Staged.
6. Press `Cmd+Z` when the undo stack is empty, confirm the app shows "Nothing to undo."

- [ ] **Step 6: Commit final verification notes if any code changed during QA**

If manual QA required code changes, run:

```bash
git add macgit macgitTests
git commit -m "fix: polish git undo staging flow"
```

Expected: commit succeeds only when there are code changes from QA. If QA required no code changes, skip this command.

## Self-Review

Spec coverage:

- Phase 0 stack behavior is covered by Task 1.
- Phase 0 command execution is covered by Task 2.
- Phase 0 menu notification routing is covered by Task 5.
- Phase 1A real Git behavior is covered by Task 3.
- Phase 1A `FileStatusView` registration is covered by Task 4.
- Verification and manual QA are covered by Task 6.

Placeholder scan:

- The plan contains concrete file paths, concrete code blocks, exact commands, and expected outcomes.
- No unspecified implementation steps remain inside the Phase 0 and Phase 1A scope.

Type consistency:

- `GitUndoOperation`, `GitUndoEntry`, `GitUndoEntryFactory`, `GitUndoManager`, `GitUndoExecutor`, `GitUndoError`, and `GitUndoMenuAction` are defined before use.
- The `GitUndoExecutor.execute(_:in:)` signature is identical in tests, menu handling, and integration usage.
- `GitUndoEntryFactory.stageFiles` and `GitUndoEntryFactory.unstageFiles` produce operations consumed directly by `GitUndoExecutor`.
